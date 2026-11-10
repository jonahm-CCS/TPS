export const areas=[{id:'weld',name:'Weld Shop',code:'WELDSHOP',icon:'⌁'},{id:'cut',name:'Laser & Waterjet',code:'CUTTING',icon:'⌗'},{id:'machine',name:'Machining',code:'CNC / MANUAL',icon:'⊞'},{id:'form',name:'Forming',code:'PRESS BRAKE',icon:'⌑'},{id:'paint',name:'Paint & Finishing',code:'FINISHING',icon:'◫'},{id:'assembly',name:'Assembly & QA',code:'ASSEMBLY / QA',icon:'◇'}];
export const initial={version:1,settings:{pdf:true,notes:true,claim:true},employees:[
{id:'jonah',name:'Jonah Mericle',area:'weld',shift:1,badge:'TPS-1001',need:false},
{id:'marcus',name:'Marcus Reed',area:'weld',shift:1,badge:'TPS-1002',need:false},
{id:'daniel',name:'Daniel Brooks',area:'weld',shift:1,badge:'TPS-1003',need:true},
{id:'luis',name:'Luis Martinez',area:'weld',shift:2,badge:'TPS-1004',need:false},
{id:'eric',name:'Eric Hayes',area:'weld',shift:2,badge:'TPS-1005',need:true},
{id:'alex',name:'Alex Turner',area:'cut',shift:1,badge:'TPS-1006',need:false},
{id:'sam',name:'Sam Parker',area:'machine',shift:1,badge:'TPS-1007',need:false},
{id:'riley',name:'Riley Cole',area:'form',shift:2,badge:'TPS-1008',need:false},
{id:'jordan',name:'Jordan Lee',area:'paint',shift:1,badge:'TPS-1009',need:false},
{id:'casey',name:'Casey Morgan',area:'assembly',shift:2,badge:'TPS-1010',need:false}],
jobs:[
{id:'74812',title:'Equipment support frame',part:'6986932-WELD',customer:'Demo customer A',area:'weld',employee:'jonah',status:'In progress',qty:12,done:4,priority:'High',due:'Nov 12',revision:'A',material:'6061-T6 aluminum',operation:'Weld assembly',notes:'Review the approved drawing and work instructions before beginning. Demo instructions only.'},
{id:'74819',title:'Mounting bracket assembly',part:'6982833-9',customer:'Demo customer B',area:'weld',employee:'marcus',status:'In progress',qty:24,done:10,priority:'Normal',due:'Nov 13',revision:'C',material:'A36 steel',operation:'Weld assembly',notes:'Verify kit quantities and drawing revision before starting.'},
{id:'74826',title:'Enclosure weldment',part:'TM-4206',customer:'Demo customer C',area:'weld',employee:null,status:'Ready',qty:8,done:0,priority:'High',due:'Nov 12',revision:'B',material:'304 stainless steel',operation:'Weld assembly',notes:'Kit staged in the Weld Shop. Confirm fit-up with the team lead.'},
{id:'74831',title:'Base plate assembly',part:'TM-6102',customer:'Demo customer A',area:'weld',employee:'luis',status:'Assigned',qty:16,done:0,priority:'Normal',due:'Nov 16',revision:'A',material:'A36 steel',operation:'Weld assembly',notes:'Assigned to second shift. Review traveler before starting.'},
{id:'74835',title:'Guard frame',part:'TM-1830',customer:'Demo customer D',area:'weld',employee:null,status:'Blocked',qty:6,done:0,priority:'Normal',due:'Nov 17',revision:'D',material:'6061-T6 aluminum',operation:'Weld assembly',notes:'Waiting on a missing kit component. Supervisor must release the hold.'},
{id:'74840',title:'Access panel blanks',part:'TM-2240',customer:'Demo customer B',area:'cut',employee:'alex',status:'In progress',qty:40,done:26,priority:'Normal',due:'Nov 13',revision:'A',material:'A36 steel',operation:'Laser cutting',notes:'Sample job.'},
{id:'74842',title:'Drive housing',part:'TM-3180',customer:'Demo customer C',area:'machine',employee:'sam',status:'In progress',qty:10,done:3,priority:'High',due:'Nov 12',revision:'B',material:'6061-T6 aluminum',operation:'CNC mill',notes:'Sample job.'},
{id:'74843',title:'Formed channel',part:'TM-5080',customer:'Demo customer A',area:'form',employee:'riley',status:'Assigned',qty:30,done:0,priority:'Normal',due:'Nov 16',revision:'A',material:'A36 steel',operation:'Press brake',notes:'Sample job.'},
{id:'74845',title:'Panel finish',part:'TM-2200',customer:'Demo customer B',area:'paint',employee:'jordan',status:'In progress',qty:20,done:12,priority:'Normal',due:'Nov 13',revision:'A',material:'A36 steel',operation:'Powder coating',notes:'Sample job.'},
{id:'74848',title:'Control cabinet',part:'TM-9010',customer:'Demo customer D',area:'assembly',employee:'casey',status:'Assigned',qty:4,done:0,priority:'Normal',due:'Nov 18',revision:'C',material:'Assembly',operation:'Assembly / QA',notes:'Sample job.'}],activity:[{text:'Demo production board initialized',time:'Sample data'}]};
export class DemoRepository{
 constructor(){try{const saved=JSON.parse(localStorage.getItem('tps-demo-v1'));this.state=saved?.version===1?saved:structuredClone(initial)}catch{this.state=structuredClone(initial)}}
 save(message){if(message)this.state.activity.unshift({text:message,time:new Date().toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})});this.state.activity=this.state.activity.slice(0,15);localStorage.setItem('tps-demo-v1',JSON.stringify(this.state));window.dispatchEvent(new Event('tps-update'))}
 reset(){this.state=structuredClone(initial);this.save()}
}
