(() => {
  'use strict';

  const STAGE_W = 1920, STAGE_H = 1080;
  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d', { alpha: false, desynchronized: true });
  const ART = {
    night: 'assets/night.png', chamber: 'assets/chamber.png', plinth: 'assets/plinth.png',
    sleepingseed: 'assets/flowers/sleepingseed.png', quietseed: 'assets/flowers/quietseed.png',
    pearlbud: 'assets/flowers/pearlbud.png', silveriris: 'assets/flowers/silveriris.png',
    azureorchid: 'assets/flowers/azureorchid.png', sunlotus: 'assets/flowers/sunlotus.png',
    stargarden: 'assets/flowers/stargarden.png'
  };
  const OUTCOME = {
    quietseed: { name: 'Quiet Seed', rarity: 'THE GARDEN RESTS', mul: 0, color:'#bcb19a', sound:'reveal_quiet', lore:'A seed returns to stillness. A new story begins with your next planting.' },
    pearlbud: { name: 'Pearl Bud', rarity: 'A SOFT AWAKENING', mul: 1.5, color:'#e6c6b9', sound:'reveal_small', lore:'A small, tender bloom opens beneath the moonlight.' },
    silveriris: { name: 'Silver Iris', rarity: 'MOONLIT PETALS', mul: 3, color:'#b3c6ed', sound:'reveal_medium', lore:'Moon-silver petals unfold in the evening air.' },
    azureorchid: { name: 'Azure Orchid', rarity: 'THE DEEP BLUE', mul: 9, color:'#83cbd9', sound:'reveal_medium', lore:'The blue orchid fills the glasshouse with a cool glow.' },
    sunlotus: { name: 'Sun Lotus', rarity: 'A GOLDEN DISCOVERY', mul: 36, color:'#f3cb82', sound:'reveal_large', lore:'A radiant lotus opens like dawn inside the night.' },
    stargarden: { name: 'Star Garden', rarity: 'A CONSTELLATION IN BLOOM', mul: 180, color:'#ead1f9', sound:'reveal_grand', lore:'A tiny garden of stars blossoms along every branch.' }
  };
  const img = {};
  const state = {
    session: null, error: '', errorUntil: 0, layout: {scale: 1, x: 0, y: 0, vw: STAGE_W, vh: STAGE_H},
    currency: 'GC', betIdx: {GC: 0, DC: 0}, balances: {GC: 0, DC: 0},
    phase: 'idle', phaseTime: 0, result: null, pendingResult: null, last: null,
    info: false, busy: false, muted: false, reducedMotion: false, hover: '', paused: false,
    hitboxes: [], time: 0, frame: 0, loadError: '', lastTick: 0
  };
  const COLORS = { gold:'#e5cf9d', white:'#f4ebd7', pale:'#bacdc0', muted:'#7d9a90', dark:'#0a2424' };
  const particles = Array.from({length: 46}, (_, i) => ({
    x: ((i*137.51) % 670)-335, y: ((i*89.41)%650)-325,
    r: .7+((i*31)%21)/12, speed: 4+(i%9)*2.3, a: .14+(i%7)*.052,
    phase: i*.93
  }));

  const sound = {
    ctx:null, master:null, music:null, buffers:{}, unlocked:false, musicSource:null,
    settings:{effects:true,music:true},
    async preload() {
      // All URLs are inside this package; there are no network services or CDNs.
      const files = ['tap','grow','reveal_quiet','reveal_small','reveal_medium','reveal_large','reveal_grand','ambience'];
      try {
        this.ctx = new (window.AudioContext || window.webkitAudioContext)();
        this.master = this.ctx.createGain(); this.master.gain.value = .48;
        this.master.connect(this.ctx.destination);
        this.music = this.ctx.createGain(); this.music.gain.value = .26;
        this.music.connect(this.master);
      } catch(e) { return; }
      await Promise.all(files.map(async name => {
        try {
          const data = await fetch('sounds/'+name+'.mp3');
          if (!data.ok) return;
          this.buffers[name] = await this.ctx.decodeAudioData(await data.arrayBuffer());
        } catch(e) { /* audio is optional; gameplay remains playable */ }
      }));
      this.updateMusic();
    },
    unlock() {
      if (!this.ctx) return;
      this.unlocked = true;
      if (this.ctx.state !== 'running') this.ctx.resume().catch(()=>{});
      this.updateMusic();
    },
    play(name, volume=1) {
      if (!this.ctx || !this.unlocked || state.muted || !this.settings.effects || !this.buffers[name] || state.paused) return;
      try {
        const source=this.ctx.createBufferSource(), gain=this.ctx.createGain();
        source.buffer=this.buffers[name]; gain.gain.value=volume;
        source.connect(gain); gain.connect(this.master); source.start();
      } catch(e) {}
    },
    updateMusic() {
      if (!this.ctx || !this.music) return;
      const should = this.unlocked && !state.muted && this.settings.music && !state.paused && !!this.buffers.ambience;
      if (!should && this.musicSource) { try {this.musicSource.stop()} catch(e){} this.musicSource=null; }
      if (should && !this.musicSource) {
        try {const source=this.ctx.createBufferSource(); source.buffer=this.buffers.ambience; source.loop=true; source.connect(this.music);source.start();this.musicSource=source;}catch(e){}
      }
    }
  };

  function clamp(n,a,b){ return Math.max(a,Math.min(b,n)); }
  function lerp(a,b,t){ return a+(b-a)*t; }
  function ease(t){t=clamp(t,0,1);return 1-Math.pow(1-t,3);}
  function money(n,c) {return c==='GC'? Math.round(n).toLocaleString('en-US') : (+n).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
  function rounded(x,y,w,h,r){ctx.beginPath();ctx.roundRect(x,y,w,h,r);}
  function fillRound(x,y,w,h,r,c) {ctx.fillStyle=c;rounded(x,y,w,h,r);ctx.fill();}
  function lineRound(x,y,w,h,r,c,width=2){ctx.strokeStyle=c;ctx.lineWidth=width;rounded(x,y,w,h,r);ctx.stroke();}
  function text(t,x,y,size=24,color=COLORS.white,align='left',font='sans',weight='normal'){
    ctx.fillStyle=color;ctx.textAlign=align;ctx.textBaseline='middle';
    ctx.font=`${weight} ${size}px ${font==='serif'? 'Georgia, "Times New Roman", serif':'"Trebuchet MS", Arial, sans-serif'}`;
    ctx.fillText(t,x,y);
  }
  function tracking(t,x,y,sz=17,space=4,color=COLORS.muted){
    ctx.save();ctx.fillStyle=color;ctx.textAlign='left';ctx.textBaseline='middle';ctx.font=`600 ${sz}px Arial, sans-serif`;
    let width=0;for(const c of t)width+=ctx.measureText(c).width+space;
    for(const c of t){ctx.fillText(c,x,y);x+=ctx.measureText(c).width+space;}
    ctx.restore();return width;
  }
  function art(key,x,y,w,h,alpha=1){ if(!img[key])return;ctx.save();ctx.globalAlpha=alpha;ctx.drawImage(img[key],x,y,w,h);ctx.restore(); }
  function button(id,x,y,w,h,onAction){state.hitboxes.push({id,x,y,w,h,action:onAction});}
  function circleIcon(cx,cy,type,col='#d7c79d',scale=1){
    ctx.save();ctx.translate(cx,cy);ctx.scale(scale,scale);ctx.strokeStyle=col;ctx.lineWidth=3.1;ctx.lineCap='round';ctx.lineJoin='round';ctx.beginPath();
    if(type==='back'){ctx.moveTo(11,-14);ctx.lineTo(-4,0);ctx.lineTo(11,14);ctx.moveTo(-4,0);ctx.lineTo(17,0);}
    else if(type==='minus'){ctx.moveTo(-11,0);ctx.lineTo(11,0);}
    else if(type==='plus'){ctx.moveTo(-10,0);ctx.lineTo(10,0);ctx.moveTo(0,-10);ctx.lineTo(0,10);}
    else if(type==='close'){ctx.moveTo(-10,-10);ctx.lineTo(10,10);ctx.moveTo(10,-10);ctx.lineTo(-10,10);}
    else if(type==='sound'){ctx.moveTo(-18,-7);ctx.lineTo(-8,-7);ctx.lineTo(0,-15);ctx.lineTo(0,15);ctx.lineTo(-8,7);ctx.lineTo(-18,7);ctx.closePath();ctx.moveTo(7,-9);ctx.quadraticCurveTo(18,0,7,9);}
    else if(type==='muted'){ctx.moveTo(-18,-7);ctx.lineTo(-8,-7);ctx.lineTo(0,-15);ctx.lineTo(0,15);ctx.lineTo(-8,7);ctx.lineTo(-18,7);ctx.closePath();ctx.moveTo(7,-9);ctx.lineTo(20,9);ctx.moveTo(20,-9);ctx.lineTo(7,9);}
    else if(type==='info'){ctx.arc(0,0,17,0,Math.PI*2);ctx.moveTo(0,-5);ctx.lineTo(0,8);ctx.moveTo(0,-11);ctx.lineTo(0,-10);}
    else if(type==='flower'){
      for(let i=0;i<6;i++){const a=i*Math.PI/3;ctx.moveTo(0,0);ctx.ellipse(Math.cos(a)*12,Math.sin(a)*12,7,12,a+Math.PI/2,0,Math.PI*2);}ctx.moveTo(4,0);ctx.arc(0,0,4,0,Math.PI*2);
    }
    ctx.stroke();ctx.restore();
  }
  function imageCover(image,x,y,w,h){
    if(!image)return;
    const s=Math.max(w/image.width,h/image.height), dw=image.width*s, dh=image.height*s;
    ctx.drawImage(image,x+(w-dw)/2,y+(h-dh)/2,dw,dh);
  }

  function drawBackground(){
    const {vw,vh,scale,x,y}=state.layout;
    ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#081b1c';ctx.fillRect(0,0,canvas.width,canvas.height);
    // Device pixels: the texture covers even extra-wide phones and 4:3 screens.
    const dpr=canvas.width/vw;
    ctx.setTransform(dpr,0,0,dpr,0,0);
    imageCover(img.night,0,0,vw,vh);
    ctx.setTransform(dpr*scale,0,0,dpr*scale,dpr*x,dpr*y);
    if(!img.night)fillRound(0,0,STAGE_W,STAGE_H,0,'#102b2a');
    ctx.save();ctx.strokeStyle='rgba(206,183,133,.15)';ctx.lineWidth=2;
    ctx.beginPath();ctx.moveTo(49,156);ctx.lineTo(1872,156);ctx.stroke();ctx.restore();
  }
  function drawPanel(x,y,w,h){fillRound(x,y,w,h,22,'rgba(5,23,23,.55)');lineRound(x,y,w,h,22,'rgba(222,203,154,.18)',1.5);}
  function ornament(cx,cy,a=1){
    ctx.save();ctx.globalAlpha=a;ctx.strokeStyle=COLORS.gold;ctx.lineWidth=1.5;
    ctx.beginPath();ctx.moveTo(cx-41,cy);ctx.lineTo(cx-10,cy);ctx.moveTo(cx+10,cy);ctx.lineTo(cx+41,cy);
    ctx.moveTo(cx,cy-10);ctx.lineTo(cx+8,cy);ctx.lineTo(cx,cy+10);ctx.lineTo(cx-8,cy);ctx.closePath();ctx.stroke();ctx.restore();
  }
  function drawTop(){
    const ready=!!state.session, busy=state.busy;
    fillRound(52,37,88,76,20,state.hover==='back'?'rgba(95,130,109,.3)':'rgba(12,40,39,.75)');
    lineRound(52,37,88,76,20,'rgba(216,198,153,.35)',1.4); circleIcon(95,75,'back');
    button('back',52,37,88,76,()=>Zoya7.exit());
    circleIcon(183,74,'flower',COLORS.gold,.78);
    tracking('THE MIDNIGHT GLASSHOUSE',228,76,17,3.9,COLORS.gold);
    text('BOTANICAL REVEALS',228,109,15,'#86a99d');

    fillRound(1260,45,68,68,17,'rgba(8,32,32,.68)');lineRound(1260,45,68,68,17,'rgba(201,182,139,.2)',1.4);
    circleIcon(1294,79,'info','#dccba9',.77);
    button('info',1260,45,68,68,()=>{state.info=true;sound.play('tap',.4);});
    fillRound(1343,45,68,68,17,'rgba(8,32,32,.68)');lineRound(1343,45,68,68,17,'rgba(201,182,139,.2)',1.4);
    circleIcon(1377,79,state.muted?'muted':'sound','#dccba9',.8);
    button('sound',1343,45,68,68,()=>{state.muted=!state.muted;sound.updateMusic();if(!state.muted)sound.play('tap',.45);});

    for(const [cur,x] of [['GC',1430],['DC',1654]]){
      const on=state.currency===cur, w=209;
      fillRound(x,41,w,81,19,on?'rgba(147,132,89,.2)':'rgba(8,32,32,.77)');
      lineRound(x,41,w,81,19,on?'#cbbb8d':'rgba(143,169,152,.28)',on?2.4:1.5);
      text(cur,x+22,66,21,on?COLORS.gold:COLORS.muted,'left','sans','bold');
      text(ready?money(state.balances[cur],cur):'—',x+23,96,26,COLORS.white,'left','sans','bold');
      if(cur==='GC'){
        fillRound(x+162,60,34,42,11,'rgba(214,185,117,.19)');circleIcon(x+179,80,'plus','#eed7a0',.64);
        button('getcoins',x+158,53,46,57,()=>Zoya7.buyCoins());
        button('GC',x,41,150,81,()=>selectCurrency('GC'));
      }else button('DC',x,41,w,81,()=>selectCurrency('DC'));
    }
    if(!ready)text('OPENING THE GLASSHOUSE',1500,144,16,COLORS.pale);
  }
  function drawLeft(){
    tracking('AN ATELIER OF CHANCE',100,250,18,4.2,'#afc0a9');
    text('Bloom',97,337,101,'#fbebd2','left','serif');
    tracking('A T E L I E R',103,410,29,3.3,'#dfc998');
    ctx.strokeStyle='rgba(222,195,141,.52)';ctx.lineWidth=2;
    ctx.beginPath();ctx.moveTo(103,460);ctx.lineTo(435,460);ctx.stroke();
    text('Every seed hides a story.',103,507,29,'#d2e0cd','left','serif');
    text('Plant one. Let the glasshouse',103,556,23,'#a2b9ad');
    text('reveal what blooms.',103,593,23,'#a2b9ad');
    ornament(278,663,.8);
    tracking('A QUIET WORLD',109,729,17,4,COLORS.muted);
    tracking('FULL OF WONDER',109,761,17,4,COLORS.muted);
  }
  function drawChamber(dt){
    const cx=967, cy=497, rx=315, ry=315;
    ctx.save();
    const gl=ctx.createRadialGradient(cx,cy+35,55,cx,cy,348);
    gl.addColorStop(0,'rgba(69,112,98,.24)');gl.addColorStop(.67,'rgba(19,63,58,.18)');gl.addColorStop(1,'rgba(12,33,33,.03)');
    ctx.fillStyle=gl;ctx.beginPath();ctx.arc(cx,cy,338,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.arc(cx,cy,302,0,Math.PI*2);ctx.clip();
    // Gentle dust floats independently of any round outcomes.
    for(const p of particles){
      const py=((p.y+state.time*p.speed+330)%660)-330;
      const px=p.x+Math.sin(state.time*.18+p.phase)*17;
      const inside=Math.max(0,1-Math.pow(px/317,2)-Math.pow(py/317,2));
      if(inside<=0)continue;
      {
        ctx.globalAlpha=p.a*(.63+.37*Math.sin(state.time*.9+p.phase))*(inside<.2?inside/.2:1);
        ctx.fillStyle='#e3ddaa';ctx.beginPath();ctx.arc(cx+px,cy+py,p.r,0,Math.PI*2);ctx.fill();
      }
    }
    ctx.globalAlpha=1;
    // A ribbon of light appears only during the outcome-independent lead-in.
    if(state.phase==='grow'){
      const intensity=state.reducedMotion?.22:.48;
      for(let i=0;i<15;i++){
        const a=state.time*1.9+i*Math.PI*2/15;
        const r=45+((state.phaseTime*80+i*11)%220);
        const px=cx+Math.cos(a)*r,py=cy+45+Math.sin(a)*r*.52;
        ctx.fillStyle=`rgba(245,213,146,${(1-r/300)*intensity})`;
        ctx.beginPath();ctx.arc(px,py,2.7+(i%3),0,Math.PI*2);ctx.fill();
      }
    }
    ctx.restore();

    // Layered subject and pedestal are separate from the chamber border.
    const fx=659,fy=206,fs=614;
    if(state.phase==='idle'){
      art('sleepingseed',fx,fy,fs,fs,.95+Math.sin(state.time*1.3)*.04);
    }else if(state.phase==='grow'){
      const scale=1+.035*Math.sin(state.time*6), w=fs*scale;
      art('sleepingseed',fx+(fs-w)/2,fy+(fs-w)/2,w,w,.88);
    }else if(state.phase==='reveal' || state.phase==='complete'){
      const key=state.result && OUTCOME[state.result.outcome]?state.result.outcome:'sleepingseed';
      const progress=state.phase==='complete'?1:ease(state.phaseTime/(state.reducedMotion?.35:1.85));
      const w=lerp(fs*.79,fs,progress); const xx=fx+(fs-w)/2,yy=fy+fs-w;
      ctx.save();ctx.beginPath();ctx.rect(fx-12,fy+fs*(1-progress)-65,fs+24,fs*progress+90);ctx.clip();
      art(key,xx,yy,w,w,progress*.98);ctx.restore();
      if(progress>.65 && state.result && state.result.multiplier>0){
        const extra=(progress-.65)/.35, bright=state.result.multiplier>=36? .5:.22;
        ctx.save();ctx.globalCompositeOperation='screen';
        const glow=ctx.createRadialGradient(cx,cy-105,10,cx,cy-105,240);
        glow.addColorStop(0,`rgba(220,222,170,${extra*bright})`);glow.addColorStop(1,'rgba(150,180,143,0)');
        ctx.fillStyle=glow;ctx.beginPath();ctx.arc(cx,cy-105,240,0,Math.PI*2);ctx.fill();ctx.restore();
      }
    }
    art('plinth',695,660,545,178);
    art('chamber',603,139,726,726);
    if(state.phase==='complete' && state.result && state.result.multiplier>0){
      const huge=state.result.multiplier>=36;const count=huge?28:12;
      ctx.save();ctx.globalCompositeOperation='screen';
      for(let i=0;i<count;i++){
        const a=(i*2.399963)+state.time*.07;
        const rad=90+(i*31%175);
        const fade=.55+.4*Math.sin(state.time*.7+i*1.8);
        ctx.globalAlpha=fade*(huge?.55:.26);
        ctx.fillStyle=huge?'#f4daae':'#c4e9d5';ctx.beginPath();
        ctx.arc(cx+Math.cos(a)*rad,cy-85+Math.sin(a)*rad*.72,2+(i%4),0,Math.PI*2);ctx.fill();
      }
      ctx.restore();
    }
  }
  function drawRight(){
    const x=1450;
    tracking('YOUR DISCOVERY',x,266,18,4.3,COLORS.gold);
    ctx.strokeStyle='rgba(207,191,145,.4)';ctx.lineWidth=1.7;
    ctx.beginPath();ctx.moveTo(x,298);ctx.lineTo(1823,298);ctx.stroke();
    const o=state.result && OUTCOME[state.result.outcome], complete=state.phase==='complete';
    if(state.phase==='grow'){
      text('A seed is waking…',x,381,31,'#d9dfcc','left','serif');
      text('The glasshouse is listening.',x,440,21,COLORS.muted);
      const n=3;for(let i=0;i<n;i++){ctx.beginPath();ctx.arc(x+15+i*32,509,4.5,0,Math.PI*2);ctx.fillStyle=`rgba(228,214,176,${.2+.5*(.5+.5*Math.sin(state.time*5+i*1.3))})`;ctx.fill();}
    }else if(complete && o){
      tracking(o.rarity,x,355,15,3.2,o.color);
      text(o.name,x,413,44,'#fff0d8','left','serif');
      fillRound(x,481,203,69,16,'rgba(182,163,118,.13)');lineRound(x,481,203,69,16,'rgba(205,190,146,.34)',1.4);
      text(`${state.result.multiplier}×`,x+101,515,39,o.color,'center','serif');
      tracking('ROUND PAYOUT',x,601,15,3.5,COLORS.muted);
      text(`${money(state.result.win,state.result.currency)} ${state.result.currency}`,x,651,34,state.result.win>0?'#f4dba8':'#c8c3ab','left','sans','bold');
      const words=o.lore.split(' ');let yy=721,line='';
      for(const word of words){if((line+' '+word).length>29){text(line.trim(),x,yy,20,'#aebfb2');yy+=30;line='';}line+=word+' ';}
      if(line)text(line.trim(),x,yy,20,'#aebfb2');
    }else {
      text('A new beginning',x,390,38,'#f0e0be','left','serif');
      text('One seed. Six possible',x,455,22,COLORS.pale);
      text('discoveries.',x,490,22,COLORS.pale);
      tracking('EVERY GROW IS A CHANCE ROUND',x,609,14,2.3,COLORS.muted);
    }
    if(state.session && state.session.demo){
      fillRound(x,818,177,40,12,'rgba(92,129,105,.2)');
      text('DEMO • PRETEND COINS',x+13,839,14,'#b6d2bd');
    }
  }
  function drawBottom(){
    fillRound(52,879,1816,158,25,'rgba(5,24,24,.9)');
    lineRound(52,879,1816,158,25,'rgba(220,200,149,.29)',2);
    tracking('SEED OFFERING',105,922,15,3.2,COLORS.muted);
    const bets=state.session ? state.session.bets[state.currency] : [100];
    const idx=clamp(state.betIdx[state.currency],0,bets.length-1);const bet=bets[idx];
    const dim=state.busy?.4:1;
    ctx.save();ctx.globalAlpha=dim;
    fillRound(100,951,68,61,16,'rgba(92,127,105,.17)');lineRound(100,951,68,61,16,'rgba(215,194,146,.42)');circleIcon(134,981,'minus');
    fillRound(178,950,245,64,16,'rgba(15,49,44,.87)');
    text(state.session?`${money(bet,state.currency)} ${state.currency}`:'…',300,982,28,COLORS.white,'center','sans','bold');
    fillRound(435,951,68,61,16,'rgba(92,127,105,.17)');lineRound(435,951,68,61,16,'rgba(215,194,146,.42)');circleIcon(469,981,'plus');
    ctx.restore();
    button('less',100,939,75,89,()=>betStep(-1));button('more',428,939,82,89,()=>betStep(1));

    // Primary action: substantial, tactile, and clearly disabled during a round.
    const bx=708,by=901,bw=468,bh=113;
    const grd=ctx.createLinearGradient(0,by,0,by+bh);
    if(state.busy){grd.addColorStop(0,'#617d70');grd.addColorStop(1,'#3c594f');}
    else {grd.addColorStop(0,'#f4e0af');grd.addColorStop(.48,'#cfb982');grd.addColorStop(1,'#a58d60');}
    ctx.save();ctx.shadowColor='rgba(212,180,107,.25)';ctx.shadowBlur=28;
    fillRound(bx,by,bw,bh,22,grd);ctx.restore();
    lineRound(bx+5,by+5,bw-10,bh-10,17,'rgba(255,247,220,.57)',2);
    circleIcon(bx+66,by+56,'flower',state.busy?'#dae5d3':'#30453a',.95);
    tracking(state.busy?'G R O W I N G':'G R O W   A   S E E D',bx+116,by+60,24,1.3,state.busy?'#f3e7cc':'#193d34');
    button('grow',bx,by,bw,bh,()=>startRound());
    ctx.strokeStyle='rgba(218,197,151,.3)';ctx.lineWidth=1.2;ctx.beginPath();ctx.moveTo(1311,921);ctx.lineTo(1311,1002);ctx.stroke();
    tracking('LAST BLOOM',1361,930,15,3.3,COLORS.muted);
    if(state.last){
      text(state.last.name,1361,968,27,'#efdfbe','left','serif');
      text(`${money(state.last.win,state.last.currency)} ${state.last.currency}`,1361,1004,20,state.last.win>0?'#d7c79c':COLORS.muted);
    }else{
      text('Awaiting a first seed',1361,972,23,'#becabd','left','serif');
    }

    if(state.error && state.time<state.errorUntil){
      const msg=state.error;ctx.save();ctx.shadowColor='#000';ctx.shadowBlur=24;
      fillRound(556,816,812,51,13,'rgba(65,40,33,.93)');
      text(msg,962,841,20,'#f7dbca','center');ctx.restore();
    }
  }
  function drawInfo(){
    // Complete, true probability table comes from the Zoya7 session, never guessed in the game.
    state.hitboxes=[];
    fillRound(0,0,STAGE_W,STAGE_H,0,'rgba(4,18,19,.81)');
    button('dismiss',0,0,STAGE_W,STAGE_H,()=>{state.info=false;});
    const x=395,y=130,w=1130,h=824;
    fillRound(x,y,w,h,32,'#102e2c');lineRound(x,y,w,h,32,'#baa77d',2.3);
    ctx.strokeStyle='rgba(200,182,134,.18)';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(x+45,y+150);ctx.lineTo(x+w-45,y+150);ctx.stroke();
    tracking('THE GLASSHOUSE GUIDE',x+66,y+77,19,4,COLORS.gold);
    text('How the garden blooms',x+66,y+121,42,'#f6e9cf','left','serif');
    fillRound(x+w-113,y+49,60,60,15,'rgba(113,141,112,.2)');circleIcon(x+w-83,y+78,'close');
    button('close',x+w-120,y+41,79,78,()=>{state.info=false;});
    text('Choose a GC or DC bet, then select GROW A SEED.',x+70,y+205,23,COLORS.pale);
    text('Zoya7 decides the result when the round starts. Your tap does not change the result.',x+70,y+243,20,'#b3c9bd');
    tracking('DISCOVERIES',x+70,y+310,17,4,COLORS.gold);
    tracking('PAYS',x+640,y+310,17,4,COLORS.gold);
    tracking('SESSION CHANCE',x+842,y+310,17,4,COLORS.gold);
    const data=state.session?.options.find(o=>o.id==='main')?.outcomes || [];
    data.forEach((o,i)=>{
      const yy=y+355+i*70,def=OUTCOME[o.id];
      if(i%2===0)fillRound(x+58,yy-22,w-115,59,8,'rgba(118,153,131,.085)');
      ctx.fillStyle=def?.color||COLORS.white;ctx.beginPath();ctx.arc(x+83,yy+7,7,0,Math.PI*2);ctx.fill();
      text(o.label,x+111,yy+7,23,'#ecdfc5');
      text(`${o.multiplier}×`,x+643,yy+7,23,'#f4dbab');
      const odds = o.chance>0 ? '1 in '+(1/o.chance).toLocaleString('en-US',{maximumFractionDigits:(1/o.chance)<100?1:0}) : '—';
      text(odds,x+841,yy+7,22,'#b6cabc');
    });
    text('Chance values are supplied by Zoya7 for this session.',x+71,y+785,19,COLORS.muted);
    // Override the dismissal hitbox: opening/closing table never triggers an underlying button.
  }
  function selectCurrency(cur){if(state.busy || !state.session || state.currency===cur)return;
    state.currency=cur;sound.play('tap',.5);}
  function betStep(delta){if(!state.session||state.busy)return;
    const arr=state.session.bets[state.currency]||[];
    state.betIdx[state.currency]=clamp(state.betIdx[state.currency]+delta,0,arr.length-1);
    sound.play('tap',.55);
  }
  async function startRound(){
    if(!state.session || state.busy || state.info || !state.session.bets[state.currency]?.length)return;
    const currency=state.currency,bet=state.session.bets[currency][state.betIdx[currency]];
    if(state.balances[currency]<bet){showError(`Not enough ${currency}.${currency==='GC'?' Use + beside GC to get coins.':''}`);return;}
    state.busy=true;state.phase='grow';state.phaseTime=0;state.result=null;state.pendingResult=null;state.error='';
    state.balances[currency]=Math.max(0,state.balances[currency]-bet); // temporary balance during the presentation
    sound.play('grow',.6);
    try {
      const r=await Zoya7.play({option:'main',currency,bet});
      if(!OUTCOME[r.outcome])throw Object.assign(new Error('Unrecognized outcome from host'),{code:'outcome'});
      state.pendingResult=r;
      // Do not let the presentation invent a result while host has not answered.
    } catch(err){
      // In case of a missing result, do NOT show an invented win or loss.
      state.balances={...state.session.balances};state.busy=false;state.phase='idle';state.phaseTime=0;
      const code=err?.code||'unknown';
      if(code==='balance')showError(`Not enough ${currency}. ${currency==='GC'?'Use + beside GC to get coins.':''}`);
      else if(code==='bet'){ resetBet();showError('Bet changed. Select an available bet and try again.'); }
      else if(code==='closed')showError('This game is unavailable. Use Back to return to the lobby.');
      else if(code==='signedout')showError('Session ended. Use Back to return to the lobby.');
      else if(code==='timeout')showError('Connection lost. Check connection before trying again.');
      else if(code==='busy')showError('Previous round is still processing. Try again.');
      else showError('Round could not complete. No result was shown.');
    }
  }
  function resetBet(){
    if(!state.session)return;
    const arr=state.session.bets[state.currency]||[];
    state.betIdx[state.currency]=Math.max(0,arr.indexOf(state.session.bet[state.currency]));
  }
  function showError(msg){state.error=msg;state.errorUntil=state.time+6.5;}
  function update(dt){
    if(state.paused)return;
    state.time+=dt;
    if(state.phase==='grow'){
      state.phaseTime+=dt;
      if(state.pendingResult && state.phaseTime>=(state.reducedMotion?.25:1.65)){
        state.result=state.pendingResult;state.pendingResult=null;
        state.phase='reveal';state.phaseTime=0;
        if(state.reducedMotion)finishReveal();
      }
    }else if(state.phase==='reveal'){
      state.phaseTime+=dt;
      if(state.phaseTime>=(state.reducedMotion?.3:2.05))finishReveal();
    }
  }
  function finishReveal(){
    if(!state.result)return;
    state.phase='complete';state.phaseTime=0;state.busy=false;
    state.balances={...state.result.balances};
    const d=OUTCOME[state.result.outcome];
    state.last={name:d.name,win:state.result.win,currency:state.result.currency};
    sound.play(d.sound,state.result.multiplier>=36?.85:.65);
  }
  function draw(){
    state.hitboxes=[];drawBackground();
    drawTop();drawLeft();drawChamber();drawRight();drawBottom();
    if(state.info)drawInfo();
    if(state.loadError){fillRound(370,390,1180,204,20,'rgba(38,29,25,.93)');text('Unable to open Bloom Atelier',960,461,40,'#e7cda8','center','serif');text(state.loadError,960,518,23,'#f1d5c9','center');}
  }
  function resize(){
    const width=window.innerWidth,height=window.innerHeight;
    const dpr=Math.min(window.devicePixelRatio||1,2.5);
    canvas.width=Math.max(1,Math.floor(width*dpr));canvas.height=Math.max(1,Math.floor(height*dpr));
    const scale=Math.min(width/STAGE_W,height/STAGE_H);
    state.layout={scale,x:(width-STAGE_W*scale)/2,y:(height-STAGE_H*scale)/2,vw:width,vh:height};
    draw();
  }
  function position(e){
    const rect=canvas.getBoundingClientRect();const x=e.clientX-rect.left,y=e.clientY-rect.top;
    return {x:(x-state.layout.x)/state.layout.scale,y:(y-state.layout.y)/state.layout.scale};
  }
  function getHit(pos){return [...state.hitboxes].reverse().find(b=>pos.x>=b.x&&pos.x<=b.x+b.w&&pos.y>=b.y&&pos.y<=b.y+b.h);}
  canvas.addEventListener('pointerdown', e=>{
    e.preventDefault();sound.unlock();const hit=getHit(position(e));
    if(hit && hit.action)hit.action();
  },{passive:false});
  canvas.addEventListener('pointermove', e=>{
    const hit=getHit(position(e));state.hover=hit?hit.id:'';canvas.style.cursor=hit?'pointer':'default';
  });
  window.addEventListener('keydown',e=>{
    if(['Space','Enter','Escape','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();
    if(e.code==='Escape'){if(state.info)state.info=false;else Zoya7.exit();return;}
    if(e.code==='ArrowLeft')betStep(-1);
    if(e.code==='ArrowRight')betStep(1);
    if(e.code==='Space'||e.code==='Enter'){sound.unlock();if(state.info)state.info=false;else startRound();}
  });
  window.addEventListener('resize',resize);
  Zoya7.on('balance', b=>{
    if(!state.busy)state.balances={...b};
    // While animating, a completed round balance is applied at the reveal.
  });
  Zoya7.on('sound', s=>{sound.settings={...s};sound.updateMusic();});
  Zoya7.on('pause',()=>{state.paused=true;sound.updateMusic();});
  Zoya7.on('resume',()=>{state.paused=false;state.lastTick=performance.now();sound.updateMusic();});

  function tick(ts){
    let dt=state.lastTick?Math.min(.045,(ts-state.lastTick)/1000):0;state.lastTick=ts;
    if(dt<0)dt=0;update(dt);draw();requestAnimationFrame(tick);
  }
  async function bootstrap(){
    resize();
    try {
      const s=await Zoya7.init();
      state.session=s;state.currency=s.currency||'GC';state.balances={...s.balances};
      state.reducedMotion=!!s.reducedMotion;sound.settings={...s.sound};
      for(const cur of ['GC','DC']){
        state.betIdx[cur]=Math.max(0,(s.bets[cur]||[]).indexOf(s.bet[cur]));
      }
      await Promise.all(Object.entries(ART).map(([k,src])=>new Promise(resolve=>{
        const i=new Image();i.onload=()=>{img[k]=i;resolve();};i.onerror=()=>resolve();i.src=src;
      })));
      draw();Zoya7.ready();
      sound.preload(); // never block the first frame on audio
    }catch(e){state.loadError='Open this game through a local web server or the Zoya7 app.';console.error(e);}
  }
  requestAnimationFrame(tick);bootstrap();

})();
