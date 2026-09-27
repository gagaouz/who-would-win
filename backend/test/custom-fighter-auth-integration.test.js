const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { mkdtemp, rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const express = require('express');
const { Pool } = require('pg');

test('Real PostgreSQL account lifecycle, replay protection, deletion serialization and receipt binding', async t => {
  const { default: EmbeddedPostgres } = await import('embedded-postgres');
  const directory = await mkdtemp(path.join(os.tmpdir(), 'ava-custom-auth-pg-'));
  const socket = net.createServer(); await new Promise(r => socket.listen(0, '127.0.0.1', r));
  const port = socket.address().port; await new Promise(r => socket.close(r));
  const database = new EmbeddedPostgres({ databaseDir: path.join(directory, 'data'), port, user: 'auth_test', password: crypto.randomUUID(),
    persistent: false, createPostgresUser: false, postgresFlags: ['-h','127.0.0.1','-k',directory], onLog:()=>{}, onError:()=>{} });
  let pool, server;
  const poolClientClosures = [];
  const realFetch = global.fetch;
  const dbModule = require('../dist/services/database'); const originalPool = dbModule.getDbPool;
  const { SignedDataVerifier } = require('@apple/app-store-server-library');
  const originalVerifier = SignedDataVerifier.prototype.verifyAndDecodeTransaction;
  try {
    await database.initialise(); await database.start();
    const client = database.getPgClient();
    pool = new Pool({ host:'127.0.0.1',port,user:client.user,password:client.password,database:'postgres',max:10 });
    // pg-pool can resolve end() after removing idle clients from its bookkeeping,
    // before their sockets actually close. Track the public client end events so
    // stopping the disposable server cannot race those outstanding connections.
    pool.on('connect', client => {
      poolClientClosures.push(new Promise(resolve => client.once('end', resolve)));
    });
    dbModule.getDbPool = () => pool;
    const auth = require('../dist/services/customFighterAuth');
    await auth.initCustomFighterAuth(); await auth.initCustomFighterAuth();
    const keys = crypto.generateKeyPairSync('rsa', { modulusLength:2048 });
    const jwk = { ...keys.publicKey.export({format:'jwk'}),kid:'test-key',alg:'RS256',use:'sig' };
    global.fetch = async (url, options) => String(url) === 'https://appleid.apple.com/auth/keys'
      ? new Response(JSON.stringify({keys:[jwk]}), {status:200}) : realFetch(url, options);
    let purge = async () => {};
    const app = express(); app.use(express.json());
    app.use('/auth',auth.createCustomFighterAuthRouter({deleteOwnerData: id => purge(id)}));
    app.get('/library', auth.requireCustomFighterOwner, (req,res) => res.json({owner:req.customFighterOwner.id}));
    server = app.listen(0,'127.0.0.1'); await new Promise(r => server.once('listening',r));
    const base = 'http://127.0.0.1:' + server.address().port;
    async function call(route, body, token, method='POST') {
      const response = await realFetch(base+route,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined});
      return {status:response.status,body:response.status===204?null:await response.json()};
    }
    let clock = 0;
    async function loginRequest(subject='test-apple-owner') {
      // Distinct source IP is not mocked: reset the disposable test rate table only.
      await pool.query('DELETE FROM custom_fighter_auth_rates');
      const challenge=(await call('/auth/challenge',{})).body;
      const now=Math.floor(Date.now()/1000);
      const claims={iss:'https://appleid.apple.com',aud:'com.whowouldin.WhoWouldWin',sub:subject,iat:now,exp:now+300,
        nonce:crypto.createHash('sha256').update(challenge.nonce).digest('hex')};
      const encode=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
      const payload=encode({alg:'RS256',kid:jwk.kid})+'.'+encode(claims);
      return {challengeID:challenge.challengeID,identityToken:payload+'.'+crypto.sign('RSA-SHA256',Buffer.from(payload),keys.privateKey).toString('base64url')};
    }
    let session;
    await t.test('challenge is single-use and sessions authorize only their verified owner',async()=>{
      const request=await loginRequest(); const first=await call('/auth/apple',request);
      assert.equal(first.status,200); session=first.body;
      assert.equal((await call('/auth/apple',request)).status,401);
      assert.equal((await call('/library',null,session.sessionToken,'GET')).body.owner,session.accountID);
      assert.equal((await call('/library',null,'x'.repeat(43),'GET')).status,401);
      assert.equal((await pool.query('SELECT token_hash FROM custom_fighter_sessions')).rows[0].token_hash.length,64);
    });
    await t.test('sign-in waits for complete remote deletion and never reactivates mid-purge',async()=>{
      const request=await loginRequest();
      let releasePurge, started;
      const inPurge=new Promise(r=>started=r); const gate=new Promise(r=>releasePurge=r);
      let calls=0; purge=async()=>{calls++;if(calls===1){started();await gate;}};
      const deletion=call('/auth/account',null,session.sessionToken,'DELETE'); await inPurge;
      let loginDone=false; const login=call('/auth/apple',request).then(v=>{loginDone=true;return v;});
      await new Promise(r=>setTimeout(r,50)); assert.equal(loginDone,false);
      assert.equal((await call('/library',null,session.sessionToken,'GET')).status,401);
      releasePurge(); assert.equal((await deletion).status,204);
      const restored=await login; assert.equal(restored.status,200); session=restored.body;
      assert.equal(calls,2); assert.equal((await call('/library',null,session.sessionToken,'GET')).status,200);
    });
    await t.test('interrupted purge keeps account closed until fresh Apple authentication finishes deletion',async()=>{
      purge=async()=>{throw Error('simulated storage outage');};
      assert.equal((await call('/auth/account',null,session.sessionToken,'DELETE')).status,503);
      assert.equal((await call('/library',null,session.sessionToken,'GET')).status,401);
      let recovered=false; purge=async()=>{recovered=true;};
      const restored=await call('/auth/apple',await loginRequest()); assert.equal(restored.status,200);
      assert.equal(recovered,true); assert.equal(restored.body.accountID,session.accountID); session=restored.body;
    });
    await t.test('an admitted delete cannot erase a reactivated account after waiting on the owner lock',async()=>{
      const lock = await pool.connect(); let purgeCalls=0;
      purge=async()=>{purgeCalls++;};
      await lock.query('SELECT pg_advisory_lock(hashtextextended($1,0))',['fighter-auth:'+session.accountID]);
      let deletion;
      try {
        deletion=call('/auth/account',null,session.sessionToken,'DELETE');
        // Observe the actual route waiting after bearer authentication, without a timing guess.
        let waiting=false;
        for(let i=0;i<100;i++) {
          const result=await pool.query("SELECT 1 FROM pg_stat_activity WHERE wait_event='advisory' AND query LIKE '%pg_advisory_lock%'");
          if(result.rowCount){waiting=true;break;}
          await new Promise(r=>setTimeout(r,10));
        }
        assert.equal(waiting,true);
        // Model the completed delete + fresh Apple sign-in that won this owner lock.
        await lock.query('UPDATE custom_fighter_accounts SET library_epoch=library_epoch+1 WHERE id=$1',[session.accountID]);
        await lock.query('DELETE FROM custom_fighter_sessions WHERE owner_id=$1',[session.accountID]);
        session={...session,sessionToken:crypto.randomBytes(32).toString('base64url')};
        await lock.query('INSERT INTO custom_fighter_sessions(token_hash,owner_id,expires_at) VALUES($1,$2,NOW()+INTERVAL \'1 day\')',
          [crypto.createHash('sha256').update(session.sessionToken).digest('hex'),session.accountID]);
      } finally {
        await lock.query('SELECT pg_advisory_unlock(hashtextextended($1,0))',['fighter-auth:'+session.accountID]); lock.release();
      }
      assert.equal((await deletion).status,401); assert.equal(purgeCalls,0);
      assert.equal((await call('/library',null,session.sessionToken,'GET')).status,200);
    });
    await t.test('notification-first receipt binds owner without overwriting newer entitlement state',async()=>{
      const now=Date.now(); const expiry=new Date(now+600000).toISOString();
      await pool.query('INSERT INTO custom_fighter_subscriptions(original_id,environment,expires_at,signed_at) VALUES($1,$2,$3,$4)', ['notify-first','Sandbox',expiry,now]);
      SignedDataVerifier.prototype.verifyAndDecodeTransaction=async()=>({bundleId:'com.whowouldin.WhoWouldWin',productId:'com.whowouldin.premium.monthly',
        originalTransactionId:'notify-first',transactionId:'txn',expiresDate:now+300000,signedDate:now-1000,environment:'Sandbox'});
      await auth.requireCustomFighterSubscription(session.accountID,'test-signed-transaction'.repeat(10));
      const row=(await pool.query('SELECT * FROM custom_fighter_subscriptions WHERE original_id=$1',['notify-first'])).rows[0];
      assert.equal(row.owner_id,session.accountID); assert.equal(new Date(row.expires_at).toISOString(),expiry);
      await pool.query('UPDATE custom_fighter_subscriptions SET revoked=true WHERE original_id=$1',['notify-first']);
      await assert.rejects(auth.requireCustomFighterSubscription(session.accountID,'test-signed-transaction'.repeat(10)),e=>e.code==='subscription_required');
    });
    await t.test('concurrent legacy receipt claims can bind only one authenticated owner',async()=>{
      const other=(await call('/auth/apple',await loginRequest('second-apple-owner'))).body;
      const now=Date.now();
      SignedDataVerifier.prototype.verifyAndDecodeTransaction=async()=>({bundleId:'com.whowouldin.WhoWouldWin',productId:'com.whowouldin.premium.annual',
        originalTransactionId:'claim-once',transactionId:'txn2',expiresDate:now+600000,signedDate:now,environment:'Sandbox'});
      const outcomes=await Promise.allSettled([session.accountID,other.accountID].map(owner=>auth.requireCustomFighterSubscription(owner,'test-signed-transaction'.repeat(10))));
      assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
      assert.equal(outcomes.find(x=>x.status==='rejected').reason.code,'subscription_owner_mismatch');
    });
  } finally {
    global.fetch=realFetch; dbModule.getDbPool=originalPool; SignedDataVerifier.prototype.verifyAndDecodeTransaction=originalVerifier;
    if(server) await new Promise(r=>server.close(r));
    await pool?.end(); await Promise.all(poolClientClosures);
    await database.stop(); await rm(directory,{recursive:true,force:true});
  }
});
