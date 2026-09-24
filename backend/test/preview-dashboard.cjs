// Local-only visual fixture; never imported by the production server.
// Run after npm run build: node test/preview-dashboard.cjs
const express = require('express');
const path = require('path');
const { renderDashboardHtml } = require('../dist/views/adminDashboard');
const app = express();
const now = Date.now();
const names = ['Axolotl', 'Pangolin', 'Snow leopard', 'Red panda', 'Capybara', 'Moon dragon', 'Mantis shrimp', 'Shoebill', 'Quokka', 'Glass frog', 'Okapi', 'Wombat', 'Narwhal'];
const creatures = Array.from({ length: 87 }, (_, i) => ({
  name: i < names.length ? names[i].toLowerCase() : `imaginary creature ${i + 1}`,
  displayName: i < names.length ? names[i] : `Imaginary creature ${i + 1}`,
  count: i % 9,
  wins: i % 3,
  lookupCount: (i * 7) % 23,
  attemptCount: i % 10,
  firstSeen: new Date(now - 3600000 * (i + 2)).toISOString(),
  lastSeen: new Date(now - 60000 * (i + 1)).toISOString(),
  opponentNames: i % 3 ? ['Lion', 'Polar bear', 'Elephant'] : [],
}));
const rankings = Array.from({length:36},(_,i)=>({id:`animal_${i}`,name:names[i%names.length],wins:55-i,battles:82-i,winRate:(55-i)/(82-i)}));
const fixture = {
  overview: {totalBattles:4133,battles24h:24,battles7d:188,customBattles:178,customAppearances:220,lastActivityAt:new Date(now-60000).toISOString()},
  custom: {totalUniqueCreatures:87,totalBattles:365,totalLookups:450,totalAttempts:78,topCreatures:creatures,generatedAt:new Date(now).toISOString(),capturedSince:new Date(now-7200000).toISOString(),retentionDays:90,capacity:5000,evictedCount:0,expiredCount:0,storageMode:'temporary-memory',truncated:false},
  animals: {topByWins:rankings,topByWinRate:rankings,topByPopularity:rankings,totalBattles:2733,generatedAt:new Date(now).toISOString()},
  recent:Array.from({length:200},(_,i)=>({id:i+1,fighter1:['Lion','Hippopotamus','Grizzly Bear','custom'][i%4],fighter2:['Elephant','Orca','Honey Badger'][i%3],winner:['Elephant','Orca','Honey Badger'][i%3],environment:['Grassland','Ocean',null][i%3],mode:['full','quick','melee'][i%3],createdAt:new Date(now-(i+1)*120000).toISOString()})),
};
app.use('/api/admin/assets', express.static(path.resolve(__dirname,'../public/admin')));
app.get('/api/admin/dashboard', (req,res)=> {
  const data = req.query.empty ? {...fixture,custom:{...fixture.custom,topCreatures:[],totalUniqueCreatures:0}} : fixture;
  res.setHeader('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; style-src 'unsafe-inline'; font-src 'self'; script-src 'nonce-local-preview'");
  res.type('html').send(renderDashboardHtml(data,'local-preview'));
});
app.listen(3919,'127.0.0.1',()=>console.log('Local dashboard fixtures: http://127.0.0.1:3919/api/admin/dashboard'));
