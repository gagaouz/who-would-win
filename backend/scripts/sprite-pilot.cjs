#!/usr/bin/env node
'use strict';
// Operator diagnostics only. Never creates an account, subscription, customer job or library asset.
const { createHash, randomUUID } = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const { isDeepStrictEqual } = require('node:util');
const RESERVE = 1_000_000, OWNER_HEADROOM = 1_000_000;
const digest = value => createHash('sha256').update(value).digest('hex');
const integer = value => Number.isSafeInteger(value) && value >= 0;
function usageBound(value) {
  if (!value || value.accountingIncomplete === true || !['image','review'].includes(value.operation) || !integer(value.inputTokens)
      || !integer(value.outputTokens) || value.inputTokens > 1_000_000 || value.outputTokens > 1_000_000
      || (value.estimatedMicrodollars !== undefined && !integer(value.estimatedMicrodollars))) return null;
  const formula = value.operation === 'image'
    ? value.inputTokens * 8 + value.outputTokens * 30
    : Math.ceil((value.inputTokens * 4 + value.outputTokens * 16) / 10);
  return Math.max(formula, value.estimatedMicrodollars ?? 0);
}
function exposure(operations, usage, uncertain = false) {
  const rows = operations.map(operation => usage.filter(item => item.operation === operation));
  const complete = !uncertain && rows.every(items => items.length === 1 && usageBound(items[0]) !== null)
    && usage.length === operations.length;
  const known = usage.reduce((sum, item) => sum + (usageBound(item) ?? (integer(item.estimatedMicrodollars) ? item.estimatedMicrodollars : 0)), 0);
  if (!operations.length && !usage.length) return { complete: !uncertain, knownMicrodollars: 0, exposureMicrodollars: uncertain ? RESERVE : 0 };
  const conservative = Math.max(100_000, Math.ceil(known / 10_000) * 10_000 * 2);
  return { complete, knownMicrodollars: known, exposureMicrodollars: complete ? conservative : Math.max(RESERVE, conservative) };
}
class PilotLedger {
  constructor(pool, limit = 5_000_000) {
    if (!integer(limit) || limit < 1 || limit > 5_000_000) throw new Error('Invalid existing beta limit');
    this.pool = pool; this.limit = limit;
  }
  async transaction(callback) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query("SELECT pg_advisory_xact_lock(hashtext('custom-fighter-ledger-v1'))");
      const result = await callback(client); await client.query('COMMIT'); return result;
    } catch (error) { await client.query('ROLLBACK').catch(() => {}); throw error; }
    finally { client.release(); }
  }
  async initialize() {
    await this.pool.query(`CREATE TABLE IF NOT EXISTS custom_fighter_operator_runs (
      id UUID PRIMARY KEY, subject_digest TEXT NOT NULL, source_digest TEXT NOT NULL,
      state TEXT NOT NULL, stage TEXT NOT NULL, budget_reserved BIGINT NOT NULL CHECK(budget_reserved>=0),
      operations JSONB NOT NULL DEFAULT '[]', usage JSONB NOT NULL DEFAULT '[]', diagnostic JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), completed_at TIMESTAMPTZ
    )`);
  }
  async reserve(id, name, sourceDigest) {
    return this.transaction(async db => {
      const existing = (await db.query('SELECT * FROM custom_fighter_operator_runs WHERE id=$1',[id])).rows[0];
      if (existing) {
        if (existing.subject_digest !== digest(name) || existing.source_digest !== sourceDigest) throw new Error('Pilot ID belongs to different input/source');
        return { existing: true, record: existing };
      }
      const busy = await db.query("SELECT id FROM custom_fighter_operator_runs WHERE state='running' LIMIT 1");
      if (busy.rows.length) throw new Error('Another operator run is unresolved; no automatic replay');
      const budget = (await db.query("SELECT * FROM custom_fighter_budgets WHERE scope='beta-lifetime-v1' FOR UPDATE")).rows[0];
      if (!budget) throw new Error('Existing application budget is missing');
      const before = Math.max(Number(budget.reserved_microdollars),Number(budget.actual_microdollars));
      if (!integer(before) || before + RESERVE + OWNER_HEADROOM > this.limit) throw new Error('Insufficient beta budget while preserving one owner request');
      await db.query("UPDATE custom_fighter_budgets SET reserved_microdollars=reserved_microdollars+$1 WHERE scope='beta-lifetime-v1'",[RESERVE]);
      await db.query(`INSERT INTO custom_fighter_operator_runs(id,subject_digest,source_digest,state,stage,budget_reserved)
        VALUES($1,$2,$3,'running','reserved',$4)`,[id,digest(name),sourceDigest,RESERVE]);
      return { existing:false };
    });
  }
  async stage(id, stage, operation) {
    return this.transaction(async db => {
      const row = (await db.query('SELECT * FROM custom_fighter_operator_runs WHERE id=$1 FOR UPDATE',[id])).rows[0];
      if (!row || row.state !== 'running') throw new Error('Pilot is no longer active');
      const operations = row.operations;
      if (operation) {
        if (!['image','review'].includes(operation) || operations.includes(operation)) throw new Error('Paid operation already dispatched');
        operations.push(operation);
      }
      await db.query('UPDATE custom_fighter_operator_runs SET stage=$2,operations=$3::jsonb WHERE id=$1',[id,stage,JSON.stringify(operations)]);
    });
  }
  async usage(id, value) {
    return this.transaction(async db => {
      const row = (await db.query('SELECT * FROM custom_fighter_operator_runs WHERE id=$1 FOR UPDATE',[id])).rows[0];
      if (!row || row.state !== 'running' || !row.operations.includes(value.operation)) throw new Error('Unexpected pilot usage');
      const clean = {operation:value.operation};
      for (const key of ['inputTokens','outputTokens','estimatedMicrodollars']) if (integer(value[key])) clean[key]=value[key];
      if (['inputTokens','outputTokens','estimatedMicrodollars'].some(key=>value[key] !== undefined && !integer(value[key]))) clean.accountingIncomplete=true;
      if (typeof value.requestId === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(value.requestId)) clean.requestId=value.requestId;
      const prior = row.usage.find(item=>item.operation===value.operation);
      if (prior) {
        if (!isDeepStrictEqual(prior,clean)) throw new Error('Conflicting duplicate provider usage');
        return;
      }
      const actual = usageBound(clean) ?? (clean.estimatedMicrodollars ?? 0);
      await db.query("UPDATE custom_fighter_budgets SET actual_microdollars=actual_microdollars+$1 WHERE scope='beta-lifetime-v1'",[actual]);
      await db.query('UPDATE custom_fighter_operator_runs SET usage=usage || $2::jsonb WHERE id=$1',[id,JSON.stringify([clean])]);
    });
  }
  async finish(id, result, uncertain) {
    return this.transaction(async db => {
      const row = (await db.query('SELECT * FROM custom_fighter_operator_runs WHERE id=$1 FOR UPDATE',[id])).rows[0];
      if (!row) throw new Error('Missing pilot');
      if (row.state !== 'running') return row;
      const cost = exposure(row.operations,row.usage,uncertain);
      const delta = cost.exposureMicrodollars - Number(row.budget_reserved);
      const updated = await db.query("UPDATE custom_fighter_budgets SET reserved_microdollars=reserved_microdollars+$1 WHERE scope='beta-lifetime-v1' AND reserved_microdollars+$1>=0 RETURNING scope",[delta]);
      if (!updated.rows.length) throw new Error('Budget invariant failed');
      const diagnostic = {...result,...cost};
      return (await db.query(`UPDATE custom_fighter_operator_runs SET state=$2,stage=$3,budget_reserved=$4,
        diagnostic=$5::jsonb,completed_at=NOW() WHERE id=$1 RETURNING *`,
        [id,result.accepted?'accepted':'rejected',result.stage,cost.exposureMicrodollars,JSON.stringify(diagnostic)])).rows[0];
    });
  }
}
function safeDiagnostic(error) {
  const code = ['content_rejected','provider_unavailable','provider_uncertain','quality_rejected'].includes(error?.code) ? error.code : 'operator_error';
  const reason = typeof error?.reason === 'string' && /^[a-z0-9_]{1,100}$/.test(error.reason) ? error.reason : undefined;
  return {code,...(reason?{reason}:{})}; // Never include arbitrary errors, SQL, responses or credentials.
}
async function runPilot({id,name,sourceDigest,ledger,provider,validate,savePack,saveOriginal,reusedOriginal}) {
  const reserved = await ledger.reserve(id,name,sourceDigest);
  if (reserved.existing) return {existing:true,record:reserved.record}; // Never replay any existing run, even after a crash.
  let stage='name_moderation', original, pack, diagnosticModerationAttempted=false, diagnosticModerationPassed=false, moderated=false, accepted=false, failure, uncertain=false;
  try {
    await ledger.stage(id,stage); await provider.moderate(name);
    if (reusedOriginal !== undefined) {
      if (!Buffer.isBuffer(reusedOriginal) || !reusedOriginal.length || reusedOriginal.length > 8*1024*1024) throw new Error('Invalid reused original');
      original=reusedOriginal;
    } else {
      stage='image_generation'; await ledger.stage(id,stage,'image');
      original=await provider.generate(name,value=>ledger.usage(id,value));
    }
    stage='image_validation'; await ledger.stage(id,stage); pack=await validate(original,randomUUID());
    stage='artwork_moderation'; await ledger.stage(id,stage); await provider.moderate(name,[pack.original,...pack.poses]); moderated=true;
    stage='artwork_review'; await ledger.stage(id,stage,'review');
    pack.manifest.archetype=await provider.review(name,pack.runtime,value=>ledger.usage(id,value));
    stage='complete'; accepted=true;
  } catch(error) { failure=safeDiagnostic(error); uncertain=failure.code==='provider_uncertain' || failure.code==='operator_error'; }
  // A validation rejection may still be useful for operator inspection, but never save an unchecked/unsafe image.
  if (original && !pack && stage==='image_validation' && failure?.code==='quality_rejected' && saveOriginal) {
    diagnosticModerationAttempted=true;
    try { await provider.moderate(name,[original]); diagnosticModerationPassed=true; } catch { /* Keep bytes only in memory. */ }
  }
  const record=await ledger.finish(id,{accepted,stage,...failure,moderationPassed:moderated,
    diagnosticModerationAttempted,diagnosticModerationPassed},uncertain);
  // Only fully moderated original/runtime PNGs are allowed on disk. Never publish to a customer library.
  if (pack && moderated && failure?.code !== 'content_rejected' && savePack) await savePack(pack);
  else if (original && diagnosticModerationPassed && saveOriginal) await saveOriginal(original);
  return {existing:false,record};
}
async function main() {
  const args=process.argv.slice(2), options={};
  for(let i=0;i<args.length;i++) {
    if(args[i]==='--execute') options.execute=true;
    else if(['--run-id','--name','--output','--original'].includes(args[i]) && args[i+1]) options[args[i].slice(2)]=args[++i];
    else throw new Error('Use --run-id UUID --name SUBJECT --output IGNORED_DIRECTORY [--original IGNORED_PNG] [--execute]');
  }
  const id=options['run-id'], name=options.name?.trim().normalize('NFC');
  if (!/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(id??'') || !name || [...name].length>24 || /[\p{Cc}\p{Cf}]/u.test(name)) throw new Error('Valid unique UUID and a 1–24 character subject required');
  const backend=path.resolve(__dirname,'..');
  const sources=['provider.js','png.js','config.js','types.js'];
  const hashes={}; for(const file of sources) hashes[file]=digest(await fs.readFile(path.join(backend,'dist/customFighters',file)));
  hashes['style-reference.png']=digest(await fs.readFile(path.join(backend,'dist/customFighters/style-reference.png')));
  const {execFileSync}=require('node:child_process');
  let reusedOriginal, reusedOriginalSHA256;
  if (options.original) {
    const originalPath=await fs.realpath(path.resolve(options.original));
    execFileSync('git',['check-ignore','--quiet',originalPath],{cwd:backend,stdio:'ignore'});
    const stat=await fs.stat(originalPath);
    if (!stat.isFile() || stat.size<1 || stat.size>8*1024*1024) throw new Error('Reused original must be an existing ignored PNG no larger than8MiB');
    reusedOriginal=await fs.readFile(originalPath);
    if (reusedOriginal.length>8*1024*1024 || !reusedOriginal.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) throw new Error('Reused original is not a bounded PNG');
    reusedOriginalSHA256=digest(reusedOriginal);
  }
  const sourceDigest=digest(JSON.stringify({...hashes,...(reusedOriginalSHA256?{reusedOriginalSHA256}:{})}));
  const output=path.resolve(options.output??path.join(backend,'..','ios/build/release-tools/pilots',id));
  execFileSync('git',['check-ignore','--quiet',output+'/pilot.json'],{cwd:backend,stdio:'ignore'});
  if(!options.execute) { console.log(JSON.stringify({execute:false,runID:id,subject:name,reservation:RESERVE,ownerHeadroom:OWNER_HEADROOM,sourceDigest,hashes,reusedOriginalSHA256,output},null,2)); return; }
  const config=require('../dist/customFighters/config');
  if(process.env.SPRITE_ONLY_SERVICE!=='true' || process.env.SPRITE_ALLOW_SANDBOX!=='true' || process.env.SPRITE_ALLOW_PRODUCTION==='true') throw new Error('Operator pilot requires the isolated Sandbox service environment');
  config.requireGenerationAvailable();
  const {getDbPool}=require('../dist/services/database'); const pool=getDbPool(); if(!pool) throw new Error('Existing budget database required');
  // Avoid printing database exceptions or credential-bearing pool errors.
  pool.removeAllListeners('error'); pool.on('error',()=>{});
  try {
    const ledger=new PilotLedger(pool,config.budgetMicrodollars()); await ledger.initialize();
    const {OpenAISpriteProvider}=require('../dist/customFighters/provider'); const {validateAndPackSheet}=require('../dist/customFighters/png');
    await fs.mkdir(output,{recursive:true,mode:0o700});
    const result=await runPilot({id,name,sourceDigest,ledger,reusedOriginal,provider:new OpenAISpriteProvider(process.env.SPRITE_OPENAI_API_KEY),validate:validateAndPackSheet,
      saveOriginal:async original=>fs.writeFile(path.join(output,'moderated-rejected-original.png'),original,{flag:'wx',mode:0o600}),
      savePack:async pack=>{for(const [filename,data] of [['original.png',pack.original],['runtime.png',pack.runtime]]) await fs.writeFile(path.join(output,filename),data,{flag:'wx',mode:0o600}); await fs.writeFile(path.join(output,'manifest.json'),JSON.stringify(pack.manifest,null,2)+'\n',{flag:'wx',mode:0o600});}});
    const record={runID:id,sourceDigest,reusedOriginalSHA256,compiledSourceHashes:hashes,subjectDigest:digest(name),existing:result.existing,
      state:result.record.state,stage:result.record.stage,budgetReserved:result.record.budget_reserved,
      operations:result.record.operations,usage:result.record.usage,diagnostic:result.record.diagnostic,
      createdAt:result.record.created_at,completedAt:result.record.completed_at,
      customerAccountCreated:false,subscriptionCreated:false,libraryPublished:false};
    const file=path.join(output,result.existing?'existing-run.json':'pilot.json');
    await fs.writeFile(file,JSON.stringify(record,null,2)+'\n',{flag:'wx',mode:0o600});
    console.log(JSON.stringify({runID:id,existing:result.existing,state:record.state,stage:record.stage,evidence:file},null,2));
    if(record.state!=='accepted') process.exitCode=2;
  } finally {await pool.end();}
}
module.exports={usageBound,exposure,PilotLedger,runPilot,safeDiagnostic};
if(require.main===module) main().catch(()=>{console.error('Operator pilot stopped. No automatic retry; inspect its durable run ID and sanitized evidence.');process.exitCode=1;});
