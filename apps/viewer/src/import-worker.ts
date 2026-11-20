import { parseSession } from "@signal-echoes/core";
self.onmessage = (event:MessageEvent<ArrayBuffer>)=>{
 try{
  const text=new TextDecoder("utf-8",{fatal:true}).decode(event.data);
  const parsed=parseSession(text);
  self.postMessage({ok:true,result:parsed});
 }catch{
  self.postMessage({ok:false,code:"INVALID_SESSION"});
 }
};
