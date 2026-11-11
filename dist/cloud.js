// Publishable key: identifies the project, not a secret. Open shared access authorized by the owner.
export const config={url:'https://yvwafebjtjawxivwfiel.supabase.co',key:'sb_publishable_JXx82mzKxfV79vSFno0BIQ_Riw4WJUB'};
export class CloudRepository {
 constructor(){this.mode='cloud';this.state=null;this.busy=false}
 async rpc(name,body={}){const r=await fetch(config.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await r.json();if(!r.ok){throw new Error(data.message||'Database request failed')}return data}
 async load(){this.state=await this.rpc('tps_snapshot');return this.state}
 async command(action,args={}){if(this.busy)throw new Error('Please wait for the previous change.');this.busy=true;try{this.state=await this.rpc('tps_command',{action,expected_revision:this.state.revision,...args});return this.state}catch(e){try{await this.load()}catch{}throw e}finally{this.busy=false}}

}
