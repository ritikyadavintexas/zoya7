(()=>{'use strict';
const canvas=document.querySelector('#game'),g=canvas.getContext('2d',{alpha:false});
const W=1920,H=1080,BOX={x:215,y:640,w:860,h:220};
const THEMES=[
 {n:'05',title:'LUCKY LEAF',sub:'THE GREEN COLLECTION',a:'#51e0a8',b:'#073e39',c:'#0e6550',icon:'♣'},
 {n:'10',title:'RUBY RUSH',sub:'THE CRIMSON COLLECTION',a:'#ff9eaa',b:'#561b39',c:'#a62c57',icon:'◆'},
 {n:'20',title:'OCEAN GLOW',sub:'THE BLUE COLLECTION',a:'#72d5ff',b:'#153866',c:'#217eaf',icon:'✦'},
 {n:'30',title:'ROYAL LUCK',sub:'THE VIOLET COLLECTION',a:'#e2b0ff',b:'#39235f',c:'#7540a4',icon:'♛'},
 {n:'50',title:'DIAMOND SKY',sub:'THE CELESTIAL COLLECTION',a:'#f7d58b',b:'#4c3a60',c:'#9271b7',icon:'✧'}
];
const PRIZES={nomatch:{symbols:['♣','✦','◆'],text:'NO MATCH',hint:'Three different symbols',tone:0},clover:{symbols:['♣','♣','♣'],text:'CLOVER TRIO',hint:'Three clovers matched',tone:1},pearl:{symbols:['●','●','●'],text:'PEARL TRIO',hint:'Three pearls matched',tone:2},ruby:{symbols:['◆','◆','◆'],text:'RUBY TRIO',hint:'Three rubies matched',tone:3},crown:{symbols:['♛','♛','♛'],text:'CROWN TRIO',hint:'Three crowns matched',tone:4},diamond:{symbols:['✧','✧','✧'],text:'DIAMOND TRIO',hint:'Three diamonds matched',tone:5}};
let vw=0,vh=0,dpr=1,scale=1,offsetX=0,offsetY=0;
let session=null,balances={GC:0,DC:0},currency='GC',ticket=0,bix={GC:0,DC:0};
let mode='loading',round=null,shownWin=0,shownRoundCurrency='GC',notice='',noticeTo=0,info=false,muted=false,paused=false,armed=false;
let foil=null,fc=null,stroke=false,prev=null,covered=new Set(),scratchRatio=0;
let elapsed=0,lastT=0,readySent=false,ambientDots=Array.from({length:58},(_,i)=>({x:(i*327.13+43)%W,y:(i*173.7+39)%H,r:1.3+i%4,a:.09+(i%7)*.018}));
const sprites=['♣','●','◆','♛','✧','✦'];
const cues={select:new Audio('sounds/select.mp3'),start:new Audio('sounds/start.mp3'),scratch:new Audio('sounds/scratch.mp3'),reveal:new Audio('sounds/reveal.mp3'),win:new Audio('sounds/win.mp3'),lose:new Audio('sounds/lose.mp3')};
Object.values(cues).forEach(a=>{a.preload='auto';a.volume=.22});const ambience=new Audio('sounds/ambience.mp3');ambience.loop=true;ambience.volume=.17;let audioUnlocked=false;let scratchAudioAt=0;function updateAmbient(){if(!audioUnlocked||muted||paused||!session?.sound?.music){ambience.pause();return;}ambience.play().catch(()=>{});}
function sound(key){if(muted||paused||!session?.sound?.effects)return;const a=cues[key];if(!a)return;try{a.pause();a.currentTime=0;a.play().catch(()=>{});}catch(e){}}
function setNote(text,seconds=3){notice=text;noticeTo=performance.now()+seconds*1000;}
function resize(){vw=innerWidth;vh=innerHeight;dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.round(vw*dpr);canvas.height=Math.round(vh*dpr);scale=Math.min(vw/W,vh/H);offsetX=(vw-W*scale)/2;offsetY=(vh-H*scale)/2;}
addEventListener('resize',resize);resize();
function rounded(x,y,w,h,r,fill,strokeColor,lineWidth=1){g.beginPath();g.roundRect(x,y,w,h,r);if(fill){g.fillStyle=fill;g.fill();}if(strokeColor){g.lineWidth=lineWidth;g.strokeStyle=strokeColor;g.stroke();}}
function text(s,x,y,size=28,color='#f6f5f4',align='left',weight=600){g.font=`${weight} ${size}px system-ui, -apple-system, Segoe UI, sans-serif`;g.textAlign=align;g.textBaseline='middle';g.fillStyle=color;g.fillText(String(s),x,y);}
function grad(x,y,w,h,stops){let a=g.createLinearGradient(x,y,x+w,y+h);for(const [p,c] of stops)a.addColorStop(p,c);return a;}
function line(x,y,x2,y2,color='#fff',lw=1){g.strokeStyle=color;g.lineWidth=lw;g.beginPath();g.moveTo(x,y);g.lineTo(x2,y2);g.stroke();}
function btn(x,y,w,h,label,kind='dark',selected=false,disabled=false){let bg=kind==='gold'?grad(x,y,w,h,[[0,'#ffe1a0'],[.5,'#d9a653'],[1,'#c48b44']]):kind==='green'?grad(x,y,w,h,[[0,'#74e7ba'],[1,'#18a879']]): selected?'#344668':'#1d2a40';rounded(x,y,w,h,15,disabled?'#27303e':bg,selected?'#91c6ea':'#526078',selected?2:1);text(label,x+w/2,y+h/2+1,kind==='gold'?30:kind==='green'?30:25,disabled?'#7c8b9d':kind==='gold'||kind==='green'?'#172330':'#e8eef7','center',750);}
function viewMoney(v,c=currency){let n=Number(v)||0;return c==='GC'?Math.round(n).toLocaleString('en-US'):n.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});}
function listBets(){return session?.bets?.[currency]||[100];}
function currentBet(){const list=listBets();return list[Math.min(bix[currency],list.length-1)]??list[0]??100;}
function base(){g.fillStyle='#080e1c';g.fillRect(0,0,vw,vh);g.save();g.translate(offsetX,offsetY);g.scale(scale,scale);
 g.fillStyle=grad(0,0,1920,1080,[[0,'#0b1325'],[.48,'#15263b'],[1,'#080f20']]);g.fillRect(0,0,W,H);
 const halo=g.createRadialGradient(750,420,75,750,420,1050);halo.addColorStop(0,'rgba(69,102,133,.22)');halo.addColorStop(1,'rgba(5,9,21,0)');g.fillStyle=halo;g.fillRect(0,0,W,H);
 ambientDots.forEach((q,i)=>{g.globalAlpha=q.a*(.75+.25*(session?.reducedMotion?0:Math.sin(elapsed*.55+i)));g.beginPath();g.arc(q.x,q.y,q.r,0,Math.PI*2);g.fillStyle='#d3eef9';g.fill();});g.globalAlpha=1;
 g.strokeStyle='rgba(207,225,248,.035)';for(let i=-600;i<2500;i+=95){line(i,0,i+800,1080,'rgba(207,225,248,.035)',1)}
}
function header(){rounded(22,18,1876,103,22,'rgba(9,16,30,.85)','#334158',1);
 btn(42,39,172,62,'←  LOBBY');
 text('SCRATCH',278,66,35,'#f6f6f1','left',850);text('ROYALE',480,66,35,'#e7bf78','left',850);
 text('FIVE TICKET COLLECTIONS',282,98,16,'#99aabe','left',700);
 btn(915,37,112,65,muted?'SOUND OFF':'SOUND', 'dark');btn(1042,37,93,65,'INFO');
 rounded(1160,39,324,63,14,currency==='GC'?'#244b44':'#17243a',currency==='GC'?'#68d5b4':'#48627b',2);
 text('GC',1180,71,25,currency==='GC'?'#8ef0c5':'#a9c7d8','left',800);text(viewMoney(balances.GC,'GC'),1265,71,28,'#fafafa','left',750);btn(1400,51,65,39,'+','green');
 rounded(1500,39,367,63,14,currency==='DC'?'#4b4263':'#17243a',currency==='DC'?'#d2a6ed':'#48627b',2);
 text('DC',1523,71,25,currency==='DC'?'#e9b9ff':'#a9c7d8','left',800);text(viewMoney(balances.DC,'DC'),1610,71,28,'#fafafa','left',750);
}
function shelf(){text('01',81,169,19,'#a9bdc8','left',750);text('CHOOSE YOUR TICKET',120,170,30,'#f3ead7','left',850);text('Tap a collection below',1820,172,21,'#99aebe','right',500);
 for(let i=0;i<5;i++){
 const t=THEMES[i],x=64+i*362,w=342,y=208,h=160,on=i===ticket;
 rounded(x,y,w,h,20,on?t.b:'#121e32',on?t.a:'#37465b',on?4:2);
 if(on){let sheen=grad(x,y,w,h,[[0,t.c+'dd'],[1,'#122132']]);rounded(x+5,y+5,w-10,h-10,17,sheen);} 
 g.save();g.globalAlpha=on?.35:.18;g.beginPath();g.arc(x+280,y+81,58,0,Math.PI*2);g.fillStyle=t.a;g.fill();g.restore();
 text(t.n,x+23,y+57,62,on?t.a:'#b9c6d6','left',900);text(t.icon,x+272,y+58,50,on?t.a:'#7f91a6','center',600);
 text(t.title,x+22,y+114,23,'#f5f5f3','left',850);text(on?'SELECTED':'TAP TO SELECT',x+22,y+141,15,on?t.a:'#96abc3','left',750);
 }
}
function ticketPlate(){const t=THEMES[ticket];const x=65,y=415,w=1160,h=560;
 g.save();g.shadowColor='#000';g.shadowBlur=30;g.shadowOffsetY=15;rounded(x,y,w,h,26,'#0a111e');g.restore();
 rounded(x,y,w,h,26,grad(x,y,w,h,[[0,t.c],[.45,t.b],[1,'#0b2435']]),t.a,4);
 rounded(x+14,y+14,w-28,h-28,18,null,'rgba(255,255,255,.24)',2);
 for(let j=0;j<2;j++){g.strokeStyle='rgba(255,255,255,.10)';g.lineWidth=2;g.beginPath();g.ellipse(x+1000,y+320,130+j*90,220+j*60,-.45,0,2*Math.PI);g.stroke();}
 text('Z O Y A 7   /   S C R A T C H    C O L L E C T I O N',x+47,y+43,18,'rgba(255,255,255,.76)','left',750);
 text(t.title,x+44,y+105,59,'#fff8e9','left',950);text('SERIES  '+t.n,x+w-43,y+103,25,t.a,'right',800);
 line(x+44,y+139,x+w-44,y+139,'rgba(255,255,255,.28)',2);
 text('MATCH ALL 3 SYMBOLS TO WIN',x+46,y+172,22,'#eef6f6','left',750);
 text('SCRATCH AREA',x+46,y+199,17,'rgba(247,246,232,.75)','left',650);
 rounded(BOX.x-15,BOX.y-15,BOX.w+30,BOX.h+30,20,'#0b1c2a','rgba(253,244,219,.78)',3);
 // Behind the foil: outcome only exists after the host has returned a round.
 rounded(BOX.x,BOX.y,BOX.w,BOX.h,11,grad(BOX.x,BOX.y,BOX.w,BOX.h,[[0,'#fff8e9'],[.55,'#fffef4'],[1,'#eee3cc']]));
 if(round){const prize=PRIZES[round.outcome]||PRIZES.nomatch;for(let j=0;j<3;j++){
 const cx=BOX.x+144+j*288;
 rounded(cx-109,BOX.y+25,218,151,15,j%2?'#e8e6dd':'#eeeadd','#cebfa9',2);
 text(prize.symbols[j],cx,BOX.y+103,110,prize.tone===0?['#158c6c','#2d7aae','#9f3671'][j]:t.c,'center',900);
 }
 text(prize.text,BOX.x+BOX.w/2,BOX.y+201,20,'#574b49','center',900);
 }else {text('3  ×  ?  ?  ?',BOX.x+BOX.w/2,BOX.y+110,62,'#b7b2a6','center',800);}
 if((mode==='scratch'||mode==='revealing')&&foil){g.drawImage(foil,BOX.x,BOX.y,BOX.w,BOX.h);}
 else if(mode==='loading'||mode==='idle'||mode==='waiting'||mode==='error'){
 let overlay=grad(BOX.x,BOX.y,BOX.w,BOX.h,[[0,'#eef4f6'],[.33,'#9facbf'],[.67,'#f4f7fc'],[1,'#9aaabd']]);rounded(BOX.x,BOX.y,BOX.w,BOX.h,10,overlay);
 g.save();g.beginPath();g.roundRect(BOX.x,BOX.y,BOX.w,BOX.h,10);g.clip();for(let k=-200;k<1100;k+=40)line(BOX.x+k,BOX.y,BOX.x+k+145,BOX.y+220,'rgba(255,255,255,.15)',8);g.restore();
 text('✦',BOX.x+170,BOX.y+83,52,'#8295a7','center');text('SCRATCH  TO  REVEAL',BOX.x+BOX.w/2,BOX.y+90,43,'#40516a','center',900);text('PLAY A TICKET TO UNLOCK',BOX.x+BOX.w/2,BOX.y+144,23,'#586f89','center',800);text('✦',BOX.x+BOX.w-170,BOX.y+83,52,'#8295a7','center');}
 text('THREE MATCHING SYMBOLS = ONE PRIZE',x+47,y+h-49,19,'#f7edcd','left',750);
 text('ORIGINAL TICKET ART   •   ' + t.sub,x+w-43,y+h-49,17,'rgba(243,244,233,.72)','right',650);
}
function sidePanel(){const x=1256,y=413,w=602,h=565;rounded(x,y,w,h,24,'#131e30','#384a5f',2);let locked=(mode==='loading'||mode==='waiting'||mode==='scratch'||mode==='revealing');
 text('02',1291,455,21,'#a5bdd1','left',750);text('SET YOUR BET',1333,455,27,'#f0eee5','left',850);
 text('Currency',1296,509,21,'#93aabd','left',600);
 btn(1460,488,168,59,'GC',currency==='GC'?'green':'dark',currency==='GC',locked);btn(1645,488,166,59,'DC','dark',currency==='DC',locked);
 text('BET AMOUNT',1297,587,18,'#a7b6c5','left',850);
 rounded(1295,614,524,95,18,'#0a1424','#42556e',2);
 btn(1308,626,88,70,'−','dark',false,locked);text(viewMoney(currentBet()),1558,663,42,'#f3f7f4','center',900);btn(1717,626,88,70,'+','dark',false,locked);
 text(currency+'  •  available bets from Zoya7',1558,733,17,'#8fa4bc','center',600);
 let label=mode==='idle'?'PLAY TICKET':mode==='waiting'?'LOADING ROUND…':mode==='scratch'?'REVEAL ALL':mode==='revealed'?'NEW TICKET':mode==='loading'?'CONNECTING…':'REVEAL ALL';
 btn(1294,769,524,94,label,mode==='idle'||mode==='revealed'?'gold':mode==='scratch'?'green':'dark',false,mode==='waiting'||mode==='loading');
 text(mode==='idle'?'Start a round, then scratch the silver foil.':mode==='waiting'?'Waiting for the confirmed Zoya7 outcome…':mode==='scratch'?'Drag to scratch, or tap REVEAL ALL.':mode==='revealed'?'Round complete. Play another ticket.':mode==='error'?'Use the instructions shown below.':'',1557,887,21,'#a9bed2','center',600);
 line(1295,915,1820,915,'#38495e',1);
 text('LAST RESULT',1295,943,19,'#a8b7c9','left',850);text(shownWin>0?'WIN  '+viewMoney(shownWin,shownRoundCurrency)+' '+shownRoundCurrency:round&&mode==='revealed'?'NO MATCH':'—',1816,943,23,shownWin>0?'#f8d58b':'#d1d5dd','right',850);
}
function status(){
 if(mode==='scratch'&&round){text('SCRATCH THE FOIL OR TAP REVEAL ALL',78,1023,24,'#dcebdd','left',850);text(Math.round(scratchRatio*100)+'% SCRATCHED',1848,1023,23,'#e9c685','right',800);}
 else if(mode==='revealed'&&round){const p=PRIZES[round.outcome]||PRIZES.nomatch;const message=round.win>0?'YOU REVEALED  '+p.text+'  •  '+round.multiplier+'×':'NO MATCH THIS ROUND';text(message,80,1023,29,round.win>0?'#f5dba2':'#b5c8d6','left',850);text(round.win>0?'+ '+viewMoney(round.win,round.currency)+' '+round.currency:'Try another ticket',1848,1023,25,round.win>0?'#8ce6c3':'#d0d7df','right',800);}
 else if(notice&&performance.now()<noticeTo){text(notice,78,1023,24,'#f3d6ab','left',750);}
 else {text(mode==='loading'?'CONNECTING TO ZOYA7…':mode==='waiting'?'CONFIRMING YOUR ROUND…':'01  PICK A TICKET      02  CHOOSE A BET      03  PLAY      04  SCRATCH',78,1023,23,'#94aabb','left',750);text('All outcomes are decided by Zoya7',1839,1023,20,'#879bae','right',600);}
 if(mode==='error'){rounded(330,738,1260,110,16,'#4b2530','#a94f60',2);text(notice||'Unable to connect. Open from a local web server.',960,792,28,'#fff2e9','center',750);}
}
function infoModal(){if(!info)return;g.fillStyle='rgba(3,7,16,.82)';g.fillRect(0,0,W,H);rounded(310,112,1300,862,30,'#132033','#88a8bf',2);
 text('HOW SCRATCH ROYALE WORKS',388,180,45,'#f9e4b6','left',850);btn(1445,142,109,67,'CLOSE');
 text('1. Choose a collection  •  2. Pick an allowed GC/DC bet  •  3. Press PLAY TICKET',388,256,26,'#f4f5f0','left',650);
 text('4. Scratch the foil (or press REVEAL ALL). Match all three symbols for the shown prize.',388,305,25,'#e0e7ef','left',550);
 text('Scratching does not affect odds or winnings. Zoya7 chooses every result.',388,350,23,'#a7bfd2','left',600);
 line(388,386,1515,386,'#3b5368',2);
 text('POSSIBLE RESULTS',399,433,25,'#f9ddaa','left',850);text('PAYOUT',1065,433,25,'#f9ddaa','left',850);text('CHANCE',1265,433,25,'#f9ddaa','left',850);
 let o=session?.options?.[ticket]?.outcomes||[];
 o.forEach((p,i)=>{const y=491+i*67;if(i%2===0)rounded(380,y-26,1152,56,11,'#203149');text(p.label,402,y,27,'#e5eff3','left',700);text(p.multiplier+'×',1072,y,28,'#e6c88f','left',800);text(p.chance>0?'1 in '+(1/p.chance<10?(1/p.chance).toFixed(1):Math.round(1/p.chance).toLocaleString()):'—',1267,y,24,'#bfcbd7','left',700);});
 text('05 / 10 / 20 / 30 / 50 are collection labels, not fixed bet amounts.',395,925,22,'#95b0c3','left',650);
}
function render(t){let dt=lastT?Math.min(.06,(t-lastT)/1000):0;lastT=t;if(!paused)elapsed+=dt;
 g.setTransform(dpr,0,0,dpr,0,0);base();header();shelf();ticketPlate();sidePanel();status();infoModal();g.restore();
 if(!readySent&&session){Zoya7.ready();readySent=true;}requestAnimationFrame(render);
}
requestAnimationFrame(render);
function px(e){const r=canvas.getBoundingClientRect();return{x:(e.clientX-r.left-offsetX)/scale,y:(e.clientY-r.top-offsetY)/scale};}
function inside(p,x,y,w,h){return p.x>=x&&p.x<=x+w&&p.y>=y&&p.y<=y+h;}
function resetFoil(){foil=document.createElement('canvas');foil.width=BOX.w;foil.height=BOX.h;fc=foil.getContext('2d',{willReadFrequently:true});const m=fc.createLinearGradient(0,0,BOX.w,BOX.h);m.addColorStop(0,'#eef6fd');m.addColorStop(.20,'#b6c4d4');m.addColorStop(.46,'#f1f8fa');m.addColorStop(.7,'#94a7bb');m.addColorStop(1,'#d6e1ed');fc.fillStyle=m;fc.fillRect(0,0,BOX.w,BOX.h);fc.strokeStyle='rgba(255,255,255,.25)';fc.lineWidth=3;for(let j=-BOX.h;j<BOX.w+BOX.h;j+=20){fc.beginPath();fc.moveTo(j,0);fc.lineTo(j+BOX.h,BOX.h);fc.stroke();}fc.fillStyle='rgba(49,69,98,.55)';fc.textAlign='center';fc.font='900 37px system-ui';fc.fillText('SCRATCH HERE',BOX.w/2,98);fc.font='bold 18px system-ui';fc.fillText('DRAG YOUR FINGER OR MOUSE ACROSS THE SILVER',BOX.w/2,142);
 covered=new Set();scratchRatio=0;prev=null;stroke=false;
}
function cutFoil(x,y,last){if(mode!=='scratch'||!foil)return;const lx=x-BOX.x,ly=y-BOX.y;if(lx<0||lx>BOX.w||ly<0||ly>BOX.h)return;
 fc.save();fc.globalCompositeOperation='destination-out';fc.strokeStyle='rgba(0,0,0,1)';fc.fillStyle='rgba(0,0,0,1)';fc.lineWidth=67;fc.lineCap='round';fc.lineJoin='round';fc.beginPath();fc.moveTo(last?last.x:lx,last?last.y:ly);fc.lineTo(lx,ly);fc.stroke();fc.beginPath();fc.arc(lx,ly,33.5,0,Math.PI*2);fc.fill();fc.restore();
 // Coverage is measured from the actual alpha of the foil, not number of pointer events.
 const a=fc.getImageData(0,0,BOX.w,BOX.h).data;let clear=0,total=0;for(let yy=7;yy<BOX.h;yy+=14)for(let xx=7;xx<BOX.w;xx+=14){total++;if(a[(yy*BOX.w+xx)*4+3]<64)clear++;}scratchRatio=clear/total;
 if(performance.now()-scratchAudioAt>160){sound('scratch');scratchAudioAt=performance.now();}
 if(scratchRatio>=.49)reveal();
}
function reveal(){if(mode!=='scratch'||!round)return;mode='revealed';notice='';foil=null;balances={...round.balances};shownWin=Number(round.win)||0;shownRoundCurrency=round.currency;sound(round.win>0?'win':'lose');}
async function play(){if(!session||(mode!=='idle'&&mode!=='revealed'))return;
 let b=currentBet(),option='ticket'+THEMES[ticket].n.replace(/^0/,'');if(balances[currency]<b){setNote('Not enough '+currency+'.'+(currency==='GC'?' Tap + beside GC for coins.':''),4);return;}
 mode='waiting';foil=null;round=null;shownWin=0;notice='';sound('start');
 try{const r=await Zoya7.play({option,currency,bet:b});if(!PRIZES[r.outcome])throw Error('Unknown outcome returned by the host');round=r;balances={...balances,[currency]:Math.max(0,Number(balances[currency])-b)};resetFoil();mode='scratch';sound('reveal');setNote('Scratch the silver panel, or tap REVEAL ALL.',3);
 }catch(err){mode='idle';if(err.code==='bet'){bix[currency]=0;setNote('Bet not allowed. Choose another bet.',4);}else if(err.code==='balance')setNote('Not enough '+currency+' for this bet.',4);else if(err.code==='closed'||err.code==='signedout')setNote('Game unavailable. Return to the lobby.',5);else if(err.code==='timeout')setNote('Connection lost. Please try again.',4);else setNote('Could not start this round. Please try again.',4);}
}
function click(p){if(info){if(inside(p,1435,130,145,95)){info=false;sound('select')}return;}
 if(inside(p,42,39,172,65)){Zoya7.exit();return;}
 if(inside(p,915,37,112,65)){muted=!muted;updateAmbient();if(!muted)sound('select');return;}
 if(inside(p,1042,37,93,65)){info=true;sound('select');return;}
 if(inside(p,1400,51,70,41)){Zoya7.buyCoins();return;}
 const locked=mode==='waiting'||mode==='scratch'||mode==='revealing'||mode==='loading';
 if(inside(p,1160,39,324,63)&&!locked){currency='GC';sound('select');return;}
 if(inside(p,1500,39,367,63)&&!locked){currency='DC';sound('select');return;}
 if(locked&&mode!=='scratch')return;
 if(!locked){for(let i=0;i<5;i++){if(inside(p,64+i*362,208,342,160)){ticket=i;round=null;shownWin=0;mode='idle';sound('select');return;}}}
 if(inside(p,1460,488,168,59)&&!locked){currency='GC';sound('select');return;}
 if(inside(p,1645,488,166,59)&&!locked){currency='DC';sound('select');return;}
 if(inside(p,1308,626,88,70)&&!locked){bix[currency]=Math.max(0,bix[currency]-1);sound('select');return;}
 if(inside(p,1717,626,88,70)&&!locked){bix[currency]=Math.min(listBets().length-1,bix[currency]+1);sound('select');return;}
 if(inside(p,1294,769,524,94)){if(mode==='scratch')reveal();else if(mode==='idle'||mode==='revealed')play();return;}
}
canvas.addEventListener('pointerdown',e=>{e.preventDefault();audioUnlocked=true;updateAmbient();const p=px(e);if(!info&&mode==='scratch'&&inside(p,BOX.x,BOX.y,BOX.w,BOX.h)){stroke=true;prev={x:p.x-BOX.x,y:p.y-BOX.y};cutFoil(p.x,p.y,null);try{canvas.setPointerCapture(e.pointerId)}catch(_){ }return;}click(p);});
canvas.addEventListener('pointermove',e=>{if(!stroke||mode!=='scratch')return;e.preventDefault();const p=px(e);cutFoil(p.x,p.y,prev);prev={x:p.x-BOX.x,y:p.y-BOX.y};});
function stop(){stroke=false;prev=null;}canvas.addEventListener('pointerup',stop);canvas.addEventListener('pointercancel',stop);
addEventListener('keydown',e=>{if(e.key==='Escape'){if(info)info=false;else Zoya7.exit();}if(e.key===' '||e.key==='Enter'){e.preventDefault();if(info)info=false;else if(mode==='scratch')reveal();else if(mode==='idle'||mode==='revealed')play();}});
Zoya7.on('balance',b=>{if(mode==='idle'||mode==='revealed')balances={...b};});Zoya7.on('pause',()=>{paused=true;ambience.pause();for(const a of Object.values(cues))a.pause();});Zoya7.on('resume',()=>{paused=false;updateAmbient();});
Zoya7.on('sound',s=>{if(!s.effects){for(const a of Object.values(cues))a.pause();}updateAmbient();});
Zoya7.init().then(s=>{session=s;currency=s.currency||'GC';balances={...s.balances};for(const cur of ['GC','DC'])bix[cur]=Math.max(0,(s.bets?.[cur]||[]).indexOf(s.bet?.[cur]));mode='idle';}).catch(err=>{mode='error';setNote('Unable to load game. Run it from a local web server.',100);});
})();
