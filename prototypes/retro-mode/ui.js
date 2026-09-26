(() => {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const names = {lion:'Lion',gorilla:'Gorilla',mossback:'Mossback'};
  const matchups = {wild:{ids:['lion','gorilla'],intro:'A mighty roar. A silverback stare. Who will win?'},custom:{ids:['mossback','lion'],intro:'A mossy shell meets a mighty mane. Who will win?'}};
  let current = 'wild', atlas, ready = false;
  const motionQuery = matchMedia('(prefers-reduced-motion: reduce)');
  $('reduce-motion').checked = motionQuery.matches;
  function energy(side,hp) { const value=Math.max(0,Math.min(100,Math.round(hp ?? 100)));$(side+'-health').setAttribute('aria-valuenow',value);$(side+'-health').firstElementChild.style.width=value+'%';$(side+'-hp').textContent=value; }
  function onEvent(event) {
    if(event.leftHP !== undefined) energy('left',event.leftHP);
    if(event.rightHP !== undefined) energy('right',event.rightHP);
    if(event.phase==='ready') return;
    if(event.text) $('narration').textContent=event.text;
    $('round-label').textContent=event.phase==='finish'?'FINISH':event.phase==='intro'?'ROUND 1':'BATTLE';
    $('speaker').textContent=event.phase==='finish'?'THE WINNER':event.phase==='intro'?'HERE WE GO':event.actor!==undefined?names[matchups[current].ids[event.actor]].toUpperCase():'THE BATTLE';
  }
  const battle = new RetroBattle($('arena'),{onEvent,onFinish:({name})=>{
    $('play').innerHTML='<span aria-hidden="true">↺</span> REPLAY BATTLE';
    $('play').disabled=false;
    $('speaker').textContent='THE WINNER';
    $('round-label').textContent='FINISH';
    $('narration').textContent=name+' takes the win! Ready for a rematch?';
  }});
  battle.setReducedMotion(motionQuery.matches);
  function reset() {
    battle.setFighters(...matchups[current].ids);
    const [left,right] = matchups[current].ids;
    $('left-name').textContent=names[left].toUpperCase();$('right-name').textContent=names[right].toUpperCase();
    $('left-health').setAttribute('aria-label',names[left]+' energy');$('right-health').setAttribute('aria-label',names[right]+' energy');
    $('arena').setAttribute('aria-label',`Pixel-art ${names[left]} and ${names[right]} facing each other in a savanna arena`);
    energy('left',100);energy('right',100);$('speaker').textContent='THE MATCHUP';$('narration').textContent=matchups[current].intro;$('round-label').textContent='READY';
    $('play').innerHTML='<span aria-hidden="true">▶</span> PLAY BATTLE';$('play').disabled=!ready;
  }
  function drawPose(canvas,id,pose=0,flip=false) {
    if(!atlas) return;
    const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,canvas.width,canvas.height);
    const [sx,sy,sw,sh]=window.RETRO_FRAMES[id][pose];
    const scale=Math.min(canvas.width*.83/378,canvas.height*.80/294),w=Math.round(sw*scale),h=Math.round(sh*scale),x=Math.round((canvas.width-w)/2),y=Math.round(canvas.height*.9-h);
    ctx.save();if(flip){ctx.translate(canvas.width,0);ctx.scale(-1,1)}ctx.drawImage(atlas,sx,sy,sw,sh,x,y,w,h);ctx.restore();
  }
  function updatePoses(){document.querySelectorAll('[data-pose]').forEach(canvas=>drawPose(canvas,$('inspect').value,+canvas.dataset.pose));}
  $('play').addEventListener('click',()=>{if(!ready)return;battle.play();$('play').innerHTML='<span aria-hidden="true">✦</span> BATTLE IN PROGRESS';$('play').disabled=true;});
  $('reset').addEventListener('click',reset);
  $('sound').addEventListener('click',()=>{const enabled=$('sound').getAttribute('aria-pressed')!=='true';$('sound').setAttribute('aria-pressed',enabled);$('sound').innerHTML='<span aria-hidden="true">♫</span> SOUND '+(enabled?'ON':'OFF');battle.setSound(enabled);});
  $('slow').addEventListener('change',()=>battle.setSpeed($('slow').checked?.65:1));
  $('reduce-motion').addEventListener('change',()=>battle.setReducedMotion($('reduce-motion').checked));
  motionQuery.addEventListener('change',event=>{$('reduce-motion').checked=event.matches;battle.setReducedMotion(event.matches);});
  $('inspect').addEventListener('change',updatePoses);
  document.querySelectorAll('[data-matchup]').forEach(button=>button.addEventListener('click',()=>{current=button.dataset.matchup;document.querySelectorAll('[data-matchup]').forEach(b=>{const selected=b===button;b.classList.toggle('selected',selected);b.setAttribute('aria-pressed',selected)});$('inspect').value=matchups[current].ids[0];updatePoses();reset();}));
  (async()=>{
    try {
      atlas=new Image();atlas.src='assets/sprites.png';await atlas.decode();if(!await battle.load('assets/sprites.png'))throw new Error('Battle atlas could not load');
      ready=true;$('load-state').hidden=true;
      document.querySelectorAll('[data-creature]').forEach(canvas=>drawPose(canvas,canvas.dataset.creature,0,canvas.dataset.flip==='true'));
      updatePoses();reset();
    }catch(error){$('load-state').textContent='SPRITES COULD NOT LOAD';$('narration').textContent='Please reload the preview to try again.';console.error(error);}
  })();
})();
