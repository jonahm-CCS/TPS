// Publishable key: identifies the project, not a secret. RLS protects all data.
export const config={url:'https://yvwafebjtjawxivwfiel.supabase.co',key:'sb_publishable_JXx82mzKxfV79vSFno0BIQ_Riw4WJUB'};
export class CloudRepository {
 constructor(){this.mode='cloud';this.state=null;this.session=null;this.busy=false;try{this.session=JSON.parse(sessionStorage.getItem('tps-auth'))}catch{}}
 remember(s){this.session=s;if(s)sessionStorage.setItem('tps-auth',JSON.stringify(s));else sessionStorage.removeItem('tps-auth')}
 async auth(path,body){const r=await fetch(config.url+'/auth/v1/'+path,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await r.json();if(!r.ok)throw new Error(data.msg||data.error_description||data.message||'Sign-in failed');return data}
 async login(email,password){const s=await this.auth('token?grant_type=password',{email,password});s.expires_at=Date.now()+s.expires_in*1000;this.remember(s);await this.load()}
 async token(){if(!this.session)throw new Error('Sign in to the shared workspace.');if(this.session.expires_at<Date.now()+60000){try{const s=await this.auth('token?grant_type=refresh_token',{refresh_token:this.session.refresh_token});s.expires_at=Date.now()+s.expires_in*1000;this.remember(s)}catch(e){this.remember(null);throw e}}return this.session.access_token}
 async rpc(name,body={}){const token=await this.token();const r=await fetch(config.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:config.key,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body)});const data=await r.json();if(!r.ok){if(r.status===401)this.remember(null);throw new Error(data.message||'Database request failed')}return data}
 async load(){this.state=await this.rpc('tps_snapshot');return this.state}
 async command(action,args={}){if(this.busy)throw new Error('Please wait for the previous change.');this.busy=true;try{this.state=await this.rpc('tps_command',{action,expected_revision:this.state.revision,...args});return this.state}catch(e){try{await this.load()}catch{}throw e}finally{this.busy=false}}
 async logout(){try{if(this.session)await fetch(config.url+'/auth/v1/logout',{method:'POST',headers:{apikey:config.key,Authorization:'Bearer '+this.session.access_token}})}finally{this.remember(null);this.state=null}}
}
