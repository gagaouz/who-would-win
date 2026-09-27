const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {mkdtemp,rm}=require('node:fs/promises');
const {tmpdir}=require('node:os');
const path=require('node:path');
const net=require('node:net');
const {Pool}=require('pg');
const {usageBound,exposure,PilotLedger,runPilot,safeDiagnostic}=require('../scripts/sprite-pilot.cjs');
let database,pool,ledger,directory;
const poolClientClosures=[];
before(async()=>{
 const {default:EmbeddedPostgres}=await import('embedded-postgres');directory=await mkdtemp(path.join(tmpdir(),'ava-operator-pilot-test-'));
 const socket=net.createServer();await new Promise(resolve=>socket.listen(0,'127.0.0.1',resolve));const port=socket.address().port;await new Promise(resolve=>socket.close(resolve));
 database=new EmbeddedPostgres({databaseDir:path.join(directory,'data'),port,user:'pilot_test',password:randomUUID(),persistent:false,createPostgresUser:false,postgresFlags:['-h','127.0.0.1','-k',directory],onLog:()=>{},onError:()=>{}});
 await database.initialise();await database.start();const client=database.getPgClient();pool=new Pool({host:'127.0.0.1',port,user:client.user,password:client.password,database:'postgres',max:8});
 // Wait for actual socket closure, not only pg-pool bookkeeping, before stopping the disposable server.
 pool.on('connect',client=>poolClientClosures.push(new Promise(resolve=>client.once('end',resolve))));
 await pool.query('CREATE TABLE custom_fighter_budgets(scope TEXT PRIMARY KEY,reserved_microdollars BIGINT NOT NULL,actual_microdollars BIGINT NOT NULL)');
 ledger=new PilotLedger(pool);await ledger.initialize();
});
after(async()=>{await pool?.end();await Promise.all(poolClientClosures);await database?.stop();if(directory)await rm(directory,{recursive:true,force:true});});
beforeEach(async()=>{await pool.query('TRUNCATE custom_fighter_operator_runs,custom_fighter_budgets');await pool.query("INSERT INTO custom_fighter_budgets VALUES('beta-lifetime-v1',1300000,80624)");});
const imageUsage={operation:'image',inputTokens:100,outputTokens:800,estimatedMicrodollars:20000};
const reviewUsage={operation:'review',inputTokens:1000,outputTokens:100,estimatedMicrodollars:500};
const provider=()=>({moderate:async()=>{},generate:async(_name,usage)=>{await usage(imageUsage);return Buffer.from('synthetic');},review:async(_name,_bytes,usage)=>{await usage(reviewUsage);return'biped';}});
const pack=()=>({original:Buffer.from('synthetic'),runtime:Buffer.from('runtime'),poses:[Buffer.from('pose')],manifest:{}});
const options=()=>({id:randomUUID(),name:'Robot',sourceDigest:'frozen-source',ledger,provider:provider(),validate:async()=>pack()});
const budget=async()=>(await pool.query('SELECT * FROM custom_fighter_budgets')).rows[0];
test('conservative accounting uses larger token bound, rounds up then doubles and never caps at reservation',()=>{
 assert.equal(usageBound(imageUsage),24800);assert.equal(usageBound(reviewUsage),560);
 assert.deepEqual(exposure(['image','review'],[imageUsage,reviewUsage]),{complete:true,knownMicrodollars:25360,exposureMicrodollars:100000});
 assert.equal(exposure(['image'],[{operation:'image',inputTokens:0,outputTokens:60000}]).exposureMicrodollars,3600000);
 assert.equal(exposure(['image','review'],[imageUsage]).complete,false);
 assert.equal(exposure(['image','review'],[imageUsage]).exposureMicrodollars,1000000);
 assert.equal(exposure(['image'],[{...imageUsage,inputTokens:undefined}]).complete,false);
 assert.equal(exposure(['image'],[imageUsage],true).exposureMicrodollars,1000000);
});
test('unique run reservation is atomic, keeps owner headroom and blocks replay/concurrent pilots',async()=>{
 const id=randomUUID();const results=await Promise.all(Array.from({length:6},()=>ledger.reserve(id,'Robot','source')));
 assert.equal(results.filter(x=>!x.existing).length,1);assert.equal(Number((await budget()).reserved_microdollars),2300000);
 await assert.rejects(()=>ledger.reserve(randomUUID(),'Robot','source'),/unresolved/);
 await assert.rejects(()=>ledger.reserve(id,'Cat','source'),/different/);
 await pool.query("UPDATE custom_fighter_operator_runs SET state='rejected'");
 await pool.query('UPDATE custom_fighter_budgets SET reserved_microdollars=3500000');
 await assert.rejects(()=>ledger.reserve(randomUUID(),'Robot','source'),/preserving one owner/);
});
test('completed pipeline settles only its own hold, records usage once and never publishes customer data',async()=>{
 const opts=options();let saves=0;opts.savePack=async()=>saves++;
 const result=await runPilot(opts);assert.equal(result.record.state,'accepted');assert.equal(saves,1);
 assert.equal(Number((await budget()).reserved_microdollars),1400000);assert.equal(Number((await budget()).actual_microdollars),105984);
 const tables=(await pool.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows.map(x=>x.tablename);
 assert.deepEqual(tables,['custom_fighter_budgets','custom_fighter_operator_runs']);
 opts.provider.generate=async()=>{throw Error('must not replay')};assert.equal((await runPilot(opts)).existing,true);
});
test('duplicate complete usage is idempotent regardless of JSONB field ordering',async()=>{
 const id=randomUUID();await ledger.reserve(id,'Robot','source');await ledger.stage(id,'image_generation','image');
 await ledger.usage(id,imageUsage);await ledger.usage(id,imageUsage);
 assert.equal(Number((await budget()).actual_microdollars),105424);
 await assert.rejects(()=>ledger.usage(id,{...imageUsage,outputTokens:801}),/Conflicting/);
});
test('timeout or missing review usage retains full reservation and records sanitized failure only',async()=>{
 const opts=options();opts.provider.review=async()=>{throw Object.assign(new Error('SECRET'),{code:'provider_uncertain'});};
 const result=await runPilot(opts);assert.equal(result.record.diagnostic.code,'provider_uncertain');
 assert.equal(Number(result.record.budget_reserved),1000000);assert.equal(Number((await budget()).reserved_microdollars),2300000);
 assert.ok(!JSON.stringify(result).includes('SECRET'));assert.deepEqual(safeDiagnostic(new Error('SECRET')),{code:'operator_error'});
});
test('PNG failure is saved for operator inspection only after separate successful image moderation',async()=>{
 const opts=options();let imageModerations=0,saved=0;
 opts.validate=async()=>{throw Object.assign(new Error('bad png'),{code:'quality_rejected',reason:'png_source_margin'});};
 opts.provider.moderate=async(_name,images)=>{if(images)imageModerations++;};opts.saveOriginal=async()=>saved++;
 const result=await runPilot(opts);assert.equal(imageModerations,1);assert.equal(saved,1);assert.equal(result.record.diagnostic.reason,'png_source_margin');
 assert.equal(result.record.diagnostic.diagnosticModerationPassed,true);assert.deepEqual(result.record.operations,['image']);assert.equal(Number(result.record.budget_reserved),100000);
});
test('failed diagnostic moderation never writes PNGs or requests semantic review',async()=>{
 const opts=options();let saved=0,reviews=0;opts.validate=async()=>{throw Object.assign(new Error(),{code:'quality_rejected'});};
 opts.provider.moderate=async(_name,images)=>{if(images)throw Object.assign(new Error(),{code:'content_rejected'});};
 opts.provider.review=async()=>reviews++;opts.saveOriginal=async()=>saved++;
 const result=await runPilot(opts);assert.equal(saved,0);assert.equal(reviews,0);assert.equal(result.record.diagnostic.diagnosticModerationPassed,false);
});

test('semantic unsafe rejection saves no pack even after artwork moderation passed',async()=>{
 const opts=options();let saved=0;
 opts.provider.review=async(_name,_bytes,usage)=>{await usage(reviewUsage);throw Object.assign(new Error('unsafe'),{code:'content_rejected',reason:'review_unsafe'});};
 opts.savePack=async()=>saved++;opts.saveOriginal=async()=>saved++;
 const result=await runPilot(opts);
 assert.equal(result.record.diagnostic.moderationPassed,true);
 assert.equal(result.record.diagnostic.code,'content_rejected');
 assert.equal(result.record.diagnostic.reason,'review_unsafe');
 assert.equal(result.record.state,'rejected');assert.equal(saved,0);
});

test('reusing original revalidates and moderates all art, charges only review and makes no image request',async()=>{
 const opts=options();const original=Buffer.from('already-generated');let generated=0,reviewed=0;const moderation=[];
 opts.reusedOriginal=original;opts.sourceDigest='compiled-plus-original-sha';
 opts.provider.generate=async()=>{generated++;throw Error('must not generate');};
 opts.validate=async value=>{assert.equal(value,original);return{...pack(),original,poses:Array.from({length:4},(_,i)=>Buffer.from('pose'+i))};};
 opts.provider.moderate=async(name,images)=>moderation.push({name,images});
 opts.provider.review=async(_name,_bytes,usage)=>{reviewed++;await usage(reviewUsage);return'biped';};
 const result=await runPilot(opts);
 assert.equal(generated,0);assert.equal(reviewed,1);assert.deepEqual(result.record.operations,['review']);
 assert.deepEqual(result.record.usage,[reviewUsage]);assert.equal(result.record.state,'accepted');
 assert.equal(moderation.length,2);assert.equal(moderation[0].images,undefined);
 assert.equal(moderation[1].images.length,5);assert.equal(moderation[1].images[0],original);
 assert.equal(Number((await budget()).actual_microdollars),80624+560);
 assert.equal(Number((await budget()).reserved_microdollars),1400000);
 assert.equal((await runPilot(opts)).existing,true);assert.equal(reviewed,1);
 await assert.rejects(()=>runPilot({...opts,sourceDigest:'different-original-sha'}),/different/);
});
