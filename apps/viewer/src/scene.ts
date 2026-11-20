import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import type { Session, RenderFrame, Vec3 } from "@signal-echoes/core";
import { CONFIG, makePathSegments, fnv1a32 } from "@signal-echoes/core";
type ViewMode = "overview" | "first" | "free";
function bloomTexture():THREE.CanvasTexture {
 const canvas=document.createElement("canvas");canvas.width=canvas.height=128;
 const ctx=canvas.getContext("2d")!;
 const radial=ctx.createRadialGradient(64,64,1,64,64,64);
 radial.addColorStop(0,"rgba(255,255,255,1)");
 radial.addColorStop(.12,"rgba(255,255,255,.95)");
 radial.addColorStop(.28,"rgba(255,255,255,.38)");
 radial.addColorStop(.62,"rgba(255,255,255,.08)");
 radial.addColorStop(1,"rgba(255,255,255,0)");
 ctx.fillStyle=radial;ctx.fillRect(0,0,128,128);
 return new THREE.CanvasTexture(canvas);
}
export function createScene(host:HTMLElement) {
 const scene=new THREE.Scene();scene.fog=new THREE.FogExp2(0x040a14,.013);
 const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true,powerPreference:"high-performance"});
 renderer.setPixelRatio(Math.min(window.devicePixelRatio,2));renderer.setSize(host.clientWidth,host.clientHeight);
 renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;
 host.appendChild(renderer.domElement);
 const camera=new THREE.PerspectiveCamera(49,Math.max(.1,host.clientWidth/host.clientHeight),.1,1000);
 camera.position.set(30,26,38);camera.lookAt(0,0,0);
 const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.dampingFactor=.055;
 controls.maxPolarAngle=Math.PI/2.02;controls.minDistance=2;controls.maxDistance=160;
 const ambient=new THREE.AmbientLight(0x356377,1);scene.add(ambient);
 const floor=new THREE.Mesh(new THREE.PlaneGeometry(600,600),new THREE.MeshBasicMaterial({color:0x04101c,transparent:true,opacity:.78,side:THREE.DoubleSide}));
 floor.rotation.x=-Math.PI/2;floor.position.y=-.08;scene.add(floor);
 const grid=new THREE.GridHelper(500,100,0x24516c,0x132940);
 (grid.material as THREE.Material).transparent=true;(grid.material as THREE.Material).opacity=.27;
 grid.position.y=-.045;scene.add(grid);
 const architecture=new THREE.Group();scene.add(architecture);
 const railMat=new THREE.MeshBasicMaterial({color:0x0b3546,transparent:true,opacity:.6});
 for(let i=-3;i<=18;i++){
  for(const side of [-1,1]){
   const pillar=new THREE.Mesh(new THREE.BoxGeometry(.28,4,.28),railMat);
   pillar.position.set(i*10,2,side*22);architecture.add(pillar);
   const base=new THREE.Mesh(new THREE.CylinderGeometry(.36,.36,.06,16),new THREE.MeshBasicMaterial({color:0x17485a,transparent:true,opacity:.5}));
   base.position.set(i*10,.03,side*22);architecture.add(base);
  }
 }
 for(const z of [-18,-12,12,18]) {
   const line=new THREE.Mesh(new THREE.BoxGeometry(220,.025,.06),new THREE.MeshBasicMaterial({color:0x1d5066,transparent:true,opacity:.55}));
   line.position.set(80,-.015,z);architecture.add(line);
 }
 const pathGroup=new THREE.Group();scene.add(pathGroup);
 const subject=new THREE.Group();scene.add(subject);
 const subjectCore=new THREE.Mesh(new THREE.SphereGeometry(.26,14,12),new THREE.MeshBasicMaterial({color:0xa7ffef}));
 subjectCore.position.y=.82;subject.add(subjectCore);
 const subjectRing=new THREE.Mesh(new THREE.RingGeometry(.7,.76,64),new THREE.MeshBasicMaterial({color:0x5affec,side:THREE.DoubleSide,transparent:true,opacity:.75}));
 subjectRing.rotation.x=-Math.PI/2;subjectRing.position.y=.05;subject.add(subjectRing);
 const vertical=new THREE.Mesh(new THREE.CylinderGeometry(.022,.022,1.1,10),new THREE.MeshBasicMaterial({color:0x63ddde,transparent:true,opacity:.55}));
 vertical.position.y=.61;subject.add(vertical);
 const ringGroup=new THREE.Group();scene.add(ringGroup);
 for(let r=1;r<=3;r++){
   const points:THREE.Vector3[]=[];
   for(let i=0;i<=95;i++){const theta=i/95*Math.PI*2;points.push(new THREE.Vector3(Math.cos(theta)*(r*2.4),.008+r*.003,Math.sin(theta)*(r*2.4)));}
   const circle=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),
    new THREE.LineBasicMaterial({color:r%2?0x2b8297:0x365e78,transparent:true,opacity:.15+r*.03}));
   ringGroup.add(circle);
 }
 const glow=bloomTexture();
 const palette={rising:0x74fff3,falling:0xffc780,stable:0xadc4ff,variable:0xeb9cff,unknown:0x82c5dd};
 const sprites:THREE.Sprite[]=[];
 for(let i=0;i<CONFIG.PARTICLE_LIMIT;i++){
   const mat=new THREE.SpriteMaterial({map:glow,color:0x72e5de,transparent:true,opacity:0,
     depthWrite:false,blending:THREE.AdditiveBlending});
   const sprite=new THREE.Sprite(mat);sprite.visible=false;sprite.renderOrder=5;scene.add(sprite);sprites.push(sprite);
 }
 let view:ViewMode="overview",session:Session|null=null,first=true,lastAnchor=new THREE.Vector3();
 function setSession(next:Session) {
   session=next;first=true;
   for(const obj of [...pathGroup.children]){pathGroup.remove(obj);const line=obj as THREE.Line;
     line.geometry.dispose();(line.material as THREE.Material).dispose();}
   const paths=makePathSegments(next.observations.self);
   for(const points of paths){
     if(points.length<2)continue;
     const curve=new THREE.CatmullRomCurve3(points.map(p=>new THREE.Vector3(p[0],.08,p[2])));
     const geometry=new THREE.TubeGeometry(curve,Math.max(12,points.length*2),.038,5,false);
     const material=new THREE.MeshBasicMaterial({color:0x5ffff1,transparent:true,opacity:.58});
     const path=new THREE.Mesh(geometry,material);pathGroup.add(path);
   }
 }
 function setView(next:ViewMode){view=next;controls.enabled=next==="free";first=true;}
 function reset(){first=true; if(view==="free") {camera.position.set(lastAnchor.x+27,22,lastAnchor.z+29);controls.target.copy(lastAnchor);controls.update();}}
 function draw(frame:RenderFrame,reducedMotion=false){
   const anchor=frame.self ? new THREE.Vector3(...frame.self) : new THREE.Vector3(0,0,0);
   anchor.y=0;lastAnchor.copy(anchor);
   subject.visible=Boolean(frame.self);if(frame.self)subject.position.copy(anchor);
   ringGroup.position.copy(anchor);
   frame.particles.forEach((p,i)=>{
     const sprite=sprites[i],mat=sprite.material as THREE.SpriteMaterial;
     sprite.visible=true;mat.opacity=p.opacity*(.38+.55*p.intensity);
     mat.color.setHex(palette[p.trend]);
     const q=1.3+p.intensity*2.0;
     sprite.scale.set(q,q,q);
     sprite.position.set(p.virtualPosition[0],p.virtualPosition[1],p.virtualPosition[2]);
   });
   for(let i=frame.particles.length;i<sprites.length;i++)sprites[i].visible=false;
   if(view==="overview"){
     const target=anchor.clone();target.y=1;
     const desired=anchor.clone().add(new THREE.Vector3(25,20,30));
     if(first||reducedMotion){camera.position.copy(desired);controls.target.copy(target);}
     else{camera.position.lerp(desired,.09);controls.target.lerp(target,.09);}
     camera.lookAt(controls.target);
   }else if(view==="first"){
     const desired=anchor.clone().add(new THREE.Vector3(-7,2.2,0));
     const target=anchor.clone().add(new THREE.Vector3(9,1.5,0));
     if(first||reducedMotion)camera.position.copy(desired);else camera.position.lerp(desired,.14);
     camera.lookAt(target);
   }else{
     if(first){camera.position.copy(anchor.clone().add(new THREE.Vector3(24,22,30)));controls.target.copy(anchor);}
     controls.update();
   }
   first=false;
   renderer.render(scene,camera);
 }
 function resize(){const w=Math.max(1,host.clientWidth),h=Math.max(1,host.clientHeight);
   camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h);}
 const observer=new ResizeObserver(resize);observer.observe(host);
 function destroy(){observer.disconnect();controls.dispose();glow.dispose();renderer.dispose();
   sprites.forEach(s=>(s.material as THREE.Material).dispose());host.replaceChildren();}
 return {setSession,setView,draw,reset,destroy};
}
