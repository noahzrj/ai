import UIKit
import SceneKit

struct Fighter { var p: CGPoint; var hp: Double; var maxHP: Double; var kind: Int }
struct Pickup { var p: CGPoint; var heart: Bool; var value: Int }
struct Shot { var p: CGPoint; var v: CGPoint; var life: Double; var damage: Double }
struct Weapon { let name: String; let damage: Double; let rate: Double; let range: Double; let speed: Double }
final class Arena: UIView {
    let lime = UIColor(red: 0.82, green: 1, blue: 0.42, alpha: 1)
    let weapons = [Weapon(name:"Bare hands",damage:24,rate:0.30,range:72,speed:0), Weapon(name:"Combat knife",damage:45,rate:0.23,range:96,speed:0), Weapon(name:"Pistol",damage:35,rate:0.28,range:850,speed:700), Weapon(name:"Shotgun",damage:25,rate:0.6,range:350,speed:550), Weapon(name:"Assault rifle",damage:29,rate:0.11,range:1000,speed:850)]
    var mode = "menu", previous = "menu", keys = Set<UInt16>(), mouse = CGPoint(x:650,y:350), firing = false
    var player = CGPoint(x:470,y:330), hp = 100.0, enemies = [Fighter](), pickups = [Pickup](), shots = [Shot](), walls = [CGRect]()
    var level = 1, unlocked = 1, wave = 1, remaining = 0, coins = 0, owned = [2], equipped = 2, activeWeapon = 2
    var cooldown = 0.0, grace = 0.0, spawnClock = 0.0, intermission = 0.0, elapsed = 0.0, earned = 0, kills = 0, won = false
    var message = "", swing = 0.0, buttons = [(CGRect,String)](), timer: Timer?, last = Date()
    let arena = CGRect(x:26,y:90,width:880,height:550)
    override var canBecomeFirstResponder: Bool { true }
    var leftTouch: UITouch?, rightTouch: UITouch?, moveVector = CGPoint.zero
    weak var world: ArenaWorld?
    var drawContext: CGContext?
    var safeBounds: CGRect { bounds.inset(by:safeAreaInsets) }
    var displayScale: CGFloat { min(safeBounds.width/1200,safeBounds.height/780) }
    var offset: CGPoint { CGPoint(x:safeBounds.minX+(safeBounds.width-1200*displayScale)/2,y:safeBounds.minY+(safeBounds.height-780*displayScale)/2) }
    func logical(_ touch:UITouch) -> CGPoint { let p = touch.location(in:self); return CGPoint(x:(p.x-offset.x)/displayScale,y:780-(p.y-offset.y)/displayScale) }
    func screenPoint(_ touch:UITouch) -> CGPoint { let p = touch.location(in:self); return CGPoint(x:(p.x-offset.x)/displayScale,y:(p.y-offset.y)/displayScale) }
    override init(frame: CGRect) {
        super.init(frame:frame)
        let d = UserDefaults.standard
        coins = max(0,d.integer(forKey:"coins")); unlocked = max(1,d.integer(forKey:"unlocked")); owned = (d.array(forKey:"owned") as? [Int] ?? [2]).filter { (0...4).contains($0) }; if !owned.contains(2) { owned.append(2) }
        equipped = d.object(forKey:"equipped") == nil ? 2 : d.integer(forKey:"equipped"); if !owned.contains(equipped) { equipped = 2 }
        // Migrate the original bare-hands starter loadout to the requested pistol.
        if equipped == 0 { equipped = 2; d.set(2,forKey:"equipped") }
        timer = Timer.scheduledTimer(withTimeInterval:1.0/60, repeats:true) { [weak self] _ in self?.step() }
        isMultipleTouchEnabled = true
        backgroundColor = .black
        NotificationCenter.default.addObserver(self,selector:#selector(lostFocus),name:UIApplication.willResignActiveNotification,object:nil)
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc func lostFocus() { keys.removeAll(); moveVector = .zero; leftTouch = nil; rightTouch = nil; firing = false; if mode == "play" { mode = "pause" }; setNeedsDisplay() }
    func save() { let d = UserDefaults.standard; d.set(coins,forKey:"coins"); d.set(unlocked,forKey:"unlocked"); d.set(owned,forKey:"owned"); d.set(equipped,forKey:"equipped") }
    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat = 14,_ color:UIColor = .white,_ bold:Bool = false) {
        guard let c = drawContext else { return }; c.saveGState(); c.translateBy(x:x,y:y+size*1.2); c.scaleBy(x:1,y:-1)
        let font = bold ? UIFont.boldSystemFont(ofSize:size) : UIFont.systemFont(ofSize:size)
        (s as NSString).draw(at:.zero,withAttributes:[.font:font,.foregroundColor:color]); c.restoreGState()
    }
    func fill(_ r:CGRect,_ c:UIColor,_ radius:CGFloat = 0) { c.setFill(); UIBezierPath(roundedRect:r,cornerRadius:radius).fill() }
    func line(_ a:CGPoint,_ b:CGPoint,_ c:UIColor,_ width:CGFloat = 3) { c.setStroke(); let p = UIBezierPath(); p.lineWidth = width; p.lineCapStyle = .round; p.move(to:a); p.addLine(to:b); p.stroke() }
    func button(_ title:String,_ rect:CGRect,_ action:String,_ primary:Bool = false) { fill(rect,primary ? lime : UIColor(white:0.20,alpha:1),8); text(title,rect.minX+14,rect.minY+12,14,primary ? .black : .white,true); buttons.append((rect,action)) }
    override func draw(_ dirtyRect:CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }; drawContext = c; c.saveGState(); defer { c.restoreGState(); drawContext = nil }; c.translateBy(x:offset.x,y:offset.y+780*displayScale); c.scaleBy(x:displayScale,y:-displayScale)
        buttons.removeAll()
        fill(CGRect(x:0,y:0,width:1200,height:780),UIColor(red:0.06,green:0.09,blue:0.075,alpha:1))
        text("STICK & SURVIVE",26,720,28,lime,true); text("NATIVE IOS • ARENA SURVIVAL",760,730,11,.lightGray)
        text("STAND YOUR GROUND.",26,670,34,.white,true)
        c.clear(arena)
        text("HEALTH  \(Int(ceil(hp)))",46,607,12,.white,true); fill(CGRect(x:46,y:593,width:160,height:6),.darkGray,3); fill(CGRect(x:46,y:593,width:160*hp/100,height:6),lime,3)
        text("LEVEL \(level)     WAVE \(wave) / 10",690,607,12,.white,true)
        if mode == "play" && intermission > 0 { text("WAVE \(wave)",405,540,30,lime,true) }
        fill(CGRect(x:926,y:90,width:248,height:550),UIColor(white:0.11,alpha:1),12)
        text("YOUR WALLET",946,605,11,.lightGray,true); text("● \(coins)",946,559,32,lime,true)
        text("LOADOUT",946,510,11,.lightGray,true); text(weapons[equipped].name,946,477,20,.white,true)
        if mode != "play" && mode != "pause" { button("Change weapon",CGRect(x:946,y:419,width:207,height:42),"weapon"); button("Level \(level)  →",CGRect(x:946,y:364,width:207,height:42),"level") }
        text("FIELD GUIDE",946,324,11,.lightGray,true)
        for (i,s) in ["Left pad      Move","Right pad     Aim & fire","Hold          Keep firing","Top right     Pause","Release       Stop firing","♥  Recover 25 health","●  Coins fund loot boxes"].enumerated() { text(s,946,294-CGFloat(i)*25,12,.lightGray) }
        text("KEEP MOVING. KEEP FIGHTING.",26,52,11,.lightGray); text("Progress saved on this device",941,52,11,.lightGray)
        if mode == "play" {
            button("Pause",CGRect(x:1040,y:660,width:110,height:42),"pause")
            fill(CGRect(x:76,y:116,width:132,height:132),UIColor(white:1,alpha:0.1),66)
            fill(CGRect(x:142+moveVector.x*40-22,y:182+moveVector.y*40-22,width:44,height:44),lime.withAlphaComponent(0.6),22)
            fill(CGRect(x:730,y:116,width:132,height:132),UIColor(white:1,alpha:0.1),66)
            text("AIM / FIRE",752,172,12,lime,true)
        }
        if mode != "play" {
            fill(arena,UIColor(white:0.035,alpha:0.92),12)
            if mode == "shop" {
                text("THE SUPPLY ROOM",300,553,12,lime,true); text("A little luck. More firepower.",215,497,30,.white,true)
                text("Weapons stay in your arsenal. Duplicates refund half the price.",225,457,13,.lightGray)
                fill(CGRect(x:165,y:257,width:280,height:163),UIColor(white:0.14,alpha:1),10)
                fill(CGRect(x:475,y:257,width:280,height:163),UIColor(white:0.14,alpha:1),10)
                text("FIELD CRATE",190,380,20,.white,true); text("Knife 50% • Pistol 35% • Shotgun 15%",190,343,11,.lightGray)
                text("ELITE CRATE",500,380,20,.white,true); text("Pistol 30% • Shotgun 40% • Rifle 30%",500,343,11,.lightGray)
                button("Open · 40 coins",CGRect(x:190,y:279,width:220,height:42),"cheap",true)
                button("Open · 100 coins",CGRect(x:500,y:279,width:220,height:42),"elite",true)
                text(message,170,218,14,lime); button("Back",CGRect(x:375,y:145,width:150,height:42),"back")
            } else if mode == "pause" {
                text("PAUSED.",345,410,46,.white,true); text("Take a breather. Your arena is waiting.",310,366,16,.lightGray)
                button("Resume →",CGRect(x:350,y:280,width:190,height:46),"resume",true)
            } else {
                text(mode == "end" ? (won ? "TEN WAVES. ALL YOURS." : "DOWN, BUT NOT DONE.") : "SMALL HERO. BIG PROBLEMS.",280,509,12,lime,true)
                text(mode == "end" ? (won ? "ARENA CLEARED." : "YOU FELL FIGHTING.") : "MAKE EVERY HIT COUNT.",195,435,42,.white,true)
                if mode == "end" { text("\(kills) enemies defeated · \(earned) coins collected · \(won ? 10 : wave-1) waves cleared",220,379,16,.lightGray); text(won ? "Victory bonus earned. A harder level is now unlocked." : "Open a crate, equip a weapon, and come back stronger.",225,345,14,.lightGray) }
                else { text("Survive 10 waves. Collect hearts and coins. Build your arsenal.",225,379,15,.lightGray); text("Left pad to move · Right pad to aim and fire",250,345,14,.lightGray) }
                button(mode == "end" ? (won ? "Next level →" : "Try again →") : "Enter the arena →",CGRect(x:240,y:255,width:230,height:48),"start",true)
                button("Visit shop",CGRect(x:490,y:255,width:170,height:48),"shop")
            }
        }
    }
    func stick(_ p:CGPoint,_ c:UIColor,_ scale:CGFloat) {
        c.setStroke(); let head = UIBezierPath(ovalIn:CGRect(x:p.x-7*scale,y:p.y+10*scale,width:14*scale,height:14*scale)); head.lineWidth = 3; head.stroke()
        let gait = mode == "play" ? sin(elapsed*10)*4 : 0
        line(CGPoint(x:p.x,y:p.y+10),CGPoint(x:p.x,y:p.y-9),c)
        line(CGPoint(x:p.x,y:p.y-9),CGPoint(x:p.x-9-gait,y:p.y-24*scale),c)
        line(CGPoint(x:p.x,y:p.y-9),CGPoint(x:p.x+9+gait,y:p.y-24*scale),c)
        line(CGPoint(x:p.x,y:p.y+5),CGPoint(x:p.x-12*scale,y:p.y-5),c)
        line(CGPoint(x:p.x,y:p.y+5),CGPoint(x:p.x+12*scale,y:p.y-5),c)
    }
    func start() {
        mode = "play"; hp = 100; player = CGPoint(x:466,y:350); enemies = []; pickups = []; shots = []; earned = 0; kills = 0; wave = 1; activeWeapon = equipped; moveVector = .zero; leftTouch = nil; rightTouch = nil; cooldown = 0; grace = 0; keys.removeAll(); firing = false
        let patterns:[[CGRect]] = [[CGRect(x:220,y:220,width:120,height:35),CGRect(x:590,y:465,width:120,height:35)],[CGRect(x:240,y:210,width:45,height:150),CGRect(x:650,y:390,width:45,height:150)],[CGRect(x:200,y:210,width:95,height:50),CGRect(x:630,y:210,width:95,height:50),CGRect(x:200,y:470,width:95,height:50),CGRect(x:630,y:470,width:95,height:50)],[CGRect(x:170,y:230,width:190,height:32),CGRect(x:550,y:450,width:190,height:32)]]
        walls = patterns[(level-1)%4].enumerated().map { index,r in
            let shift = CGFloat((level-1)/4%7)*12
            return r.offsetBy(dx:index%2 == 0 ? shift : -shift,dy:CGFloat((level-1)/28%5)*8)
        }; beginWave()
    }
    func beginWave() { remaining = 3+wave*2+min(level-1,30)*2; intermission = 1.8; spawnClock = 0.2 }
    func distance(_ a:CGPoint,_ b:CGPoint) -> Double { hypot(a.x-b.x,a.y-b.y) }
    func blocked(_ p:CGPoint,_ radius:CGFloat) -> Bool { walls.contains { $0.insetBy(dx:-radius,dy:-radius).contains(p) } }
    func move(_ p:inout CGPoint,_ dx:Double,_ dy:Double) {
        let x = max(arena.minX+18,min(arena.maxX-18,p.x+dx)); if !blocked(CGPoint(x:x,y:p.y),15) { p.x = x }
        let y = max(arena.minY+27,min(arena.maxY-27,p.y+dy)); if !blocked(CGPoint(x:p.x,y:y),15) { p.y = y }
    }
    func spawn() {
        let side = Int.random(in:0...3); var p = CGPoint(x:CGFloat.random(in:arena.minX+30...arena.maxX-30),y:CGFloat.random(in:arena.minY+35...arena.maxY-35))
        if side == 0 { p.x = arena.minX+22 }; if side == 1 { p.x = arena.maxX-22 }; if side == 2 { p.y = arena.minY+32 }; if side == 3 { p.y = arena.maxY-32 }
        let r = Double.random(in:0...1), kind = wave >= 5 && r < 0.2 ? 2 : wave >= 3 && r < 0.45 ? 1 : 0
        let health = (kind == 2 ? 155.0 : kind == 1 ? 45.0 : 65.0)*(1+Double(level-1)*0.25)
        enemies.append(Fighter(p:p,hp:health,maxHP:health,kind:kind))
    }
    func damage(_ index:Int,_ amount:Double) {
        guard enemies[index].hp > 0 else { return }; enemies[index].hp -= amount
        if enemies[index].hp <= 0 { kills += 1; pickups.append(Pickup(p:enemies[index].p,heart:false,value:enemies[index].kind == 2 ? 6 : 3+level/3)); if Double.random(in:0...1) < 0.19 { pickups.append(Pickup(p:CGPoint(x:enemies[index].p.x+18,y:enemies[index].p.y),heart:true,value:25)) } }
    }
    func attack() {
        let w = weapons[activeWeapon], a = atan2(mouse.y-player.y,mouse.x-player.x); cooldown = w.rate
        if w.speed == 0 { swing = 0.13; for i in enemies.indices { let b = atan2(enemies[i].p.y-player.y,enemies[i].p.x-player.x); if distance(player,enemies[i].p) < w.range && abs(atan2(sin(a-b),cos(a-b))) < 1.2 { damage(i,w.damage) } } }
        else { for i in 0..<(activeWeapon == 3 ? 5 : 1) { let angle = a+(activeWeapon == 3 ? Double(i-2)*0.13 : 0); shots.append(Shot(p:CGPoint(x:player.x+cos(angle)*23,y:player.y+sin(angle)*23),v:CGPoint(x:cos(angle)*w.speed,y:sin(angle)*w.speed),life:w.range/w.speed,damage:w.damage)) } }
    }
    func end(_ victory:Bool) { won = victory; mode = "end"; keys.removeAll(); firing = false; if victory { coins += 50+level*10; unlocked = max(unlocked,level+1); level += 1 }; save() }
    func step() {
        let now = Date(), dt = min(0.033,now.timeIntervalSince(last)); last = now
        defer { world?.update(self) }
        guard mode == "play" else { setNeedsDisplay(); return }
        elapsed += dt; cooldown -= dt; grace -= dt; swing -= dt
        var movement = moveVector
        if keys.contains(13) { movement.y += 1 }; if keys.contains(1) { movement.y -= 1 }
        if keys.contains(0) { movement.x -= 1 }; if keys.contains(2) { movement.x += 1 }
        let magnitude = max(1,hypot(movement.x,movement.y))
        move(&player,Double(movement.x/magnitude)*215*dt,Double(movement.y/magnitude)*215*dt)
        if (firing || keys.contains(49)) && cooldown <= 0 { attack() }
        if intermission > 0 { intermission -= dt } else if remaining > 0 { spawnClock -= dt; if spawnClock <= 0 { spawn(); remaining -= 1; spawnClock = max(0.15,0.8-Double(wave)*0.035-Double(level)*0.025) } }
        for i in enemies.indices where enemies[i].hp > 0 {
            let a = atan2(player.y-enemies[i].p.y,player.x-enemies[i].p.x), speed = (enemies[i].kind == 2 ? 48.0 : enemies[i].kind == 1 ? 130.0 : 78.0)*(1+Double(min(level-1,30))*0.055)
            var p = enemies[i].p; let old = p; move(&p,cos(a)*speed*dt,sin(a)*speed*dt)
            if distance(old,p) < 0.1 { move(&p,cos(a+1.3)*speed*dt,sin(a+1.3)*speed*dt) }; enemies[i].p = p
            if distance(p,player) < 29 && grace <= 0 { hp = max(0,hp-Double(enemies[i].kind == 2 ? 22 : 10+min(level,25))); grace = 0.7; if hp <= 0 { end(false); setNeedsDisplay(); return } }
        }
        for i in shots.indices {
            shots[i].life -= dt; shots[i].p.x += shots[i].v.x*dt; shots[i].p.y += shots[i].v.y*dt
            if blocked(shots[i].p,2) || !arena.contains(shots[i].p) { shots[i].life = 0 }
            if shots[i].life > 0 { for j in enemies.indices where enemies[j].hp > 0 { if distance(shots[i].p,enemies[j].p) < 20 { damage(j,shots[i].damage); shots[i].life = 0; break } } }
        }
        shots.removeAll { $0.life <= 0 }; enemies.removeAll { $0.hp <= 0 }
        for i in pickups.indices.reversed() {
            let dist = distance(player,pickups[i].p)
            if dist < 85 { pickups[i].p.x += (player.x-pickups[i].p.x)*dt*5; pickups[i].p.y += (player.y-pickups[i].p.y)*dt*5 }
            if dist < 25 { if pickups[i].heart { hp = min(100,hp+25) } else { coins += pickups[i].value; earned += pickups[i].value; save() }; pickups.remove(at:i) }
        }
        if remaining == 0 && enemies.isEmpty && intermission <= 0 { if wave == 10 { end(true) } else { wave += 1; beginWave() } }
        setNeedsDisplay()
    }
    func openCrate(_ elite:Bool) {
        let cost = elite ? 100 : 40; guard coins >= cost else { message = "You need \(cost-coins) more coins for this crate."; return }
        coins -= cost; let r = Double.random(in:0...1); let item = elite ? (r < 0.3 ? 2 : r < 0.7 ? 3 : 4) : (r < 0.5 ? 1 : r < 0.85 ? 2 : 3)
        if owned.contains(item) { coins += cost/2; message = "Duplicate \(weapons[item].name). \(cost/2) coins returned." } else { owned.append(item); equipped = item; message = "Unlocked \(weapons[item].name)! Equipped for your next run." }; save()
    }
    func activate(_ p:CGPoint) {
        guard let action = buttons.first(where: { $0.0.contains(p) })?.1 else { return }
        switch action {
        case "start": start()
        case "shop": previous = mode; mode = "shop"; message = ""
        case "back": mode = previous
        case "cheap": openCrate(false)
        case "elite": openCrate(true)
        case "weapon": equipped = owned[(owned.firstIndex(of:equipped)!+1)%owned.count]; save()
        case "level": level = level%unlocked+1
        case "resume": mode = "play"
        case "pause": mode = "pause"; keys.removeAll(); firing = false; moveVector = .zero; leftTouch = nil; rightTouch = nil
        default: break
        }; setNeedsDisplay()
    }
    func updateControl(_ touch:UITouch) {
        let p = logical(touch)
        if touch === leftTouch {
            let dx = (p.x-142)/55, dy = (p.y-182)/55, n = max(1,hypot(dx,dy)); moveVector = CGPoint(x:dx/n,y:dy/n)
        } else if touch === rightTouch {
            let dx = p.x-796, dy = p.y-182
            if hypot(dx,dy) > 9 { mouse = CGPoint(x:player.x+dx*4,y:player.y+dy*4) }; firing = true
        }
    }
    func keyboardCode(_ press:UIPress) -> UInt16? {
        switch press.key?.charactersIgnoringModifiers.lowercased() {
        case "w": return 13
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case " ": return 49
        default: return nil
        }
    }
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        for press in presses { if let code = keyboardCode(press) { keys.insert(code) } }
        super.pressesBegan(presses,with:event)
    }
    override func pressesEnded(_ presses:Set<UIPress>,with event:UIPressesEvent?) {
        for press in presses { if let code = keyboardCode(press) { keys.remove(code) } }
        super.pressesEnded(presses,with:event)
    }
    override func pressesCancelled(_ presses:Set<UIPress>,with event:UIPressesEvent?) { pressesEnded(presses,with:event) }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        for t in touches {
            let p = logical(t)
            if mode != "play" || buttons.contains(where: { $0.0.contains(p) }) { activate(p); continue }
            if p.x < 470 && leftTouch == nil { leftTouch = t; updateControl(t) }
            else if p.x >= 470 && rightTouch == nil { rightTouch = t; updateControl(t) }
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) { if mode == "play" { for t in touches { updateControl(t) } } }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) { for t in touches { if t === leftTouch { leftTouch = nil; moveVector = .zero }; if t === rightTouch { rightTouch = nil; firing = false } } }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) { touchesEnded(touches,with:event) }
}
final class ArenaWorld:SCNView {
    let stage = SCNScene()
    let actors = SCNNode()
    let terrain = SCNNode()
    var actorPool = [SCNNode]()
    var terrainLevel = -1
    var terrainWalls = [CGRect]()
    override init(frame:CGRect,options:[String:Any]? = nil) {
        super.init(frame:frame,options:options)
        scene = stage
        backgroundColor = UIColor(red:0.04,green:0.08,blue:0.12,alpha:1)
        isUserInteractionEnabled = false
        antialiasingMode = .multisampling4X
        preferredFramesPerSecond = 60
        isPlaying = true
        stage.rootNode.addChildNode(terrain)
        stage.rootNode.addChildNode(actors)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 3.5
        camera.position = SCNVector3(0,12,10)
        camera.look(at:SCNVector3Zero)
        stage.rootNode.addChildNode(camera)
        pointOfView = camera
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        sun.light?.castsShadow = true
        sun.light?.shadowRadius = 4
        sun.eulerAngles = SCNVector3(-Float.pi/3,-Float.pi/5,0)
        stage.rootNode.addChildNode(sun)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        stage.rootNode.addChildNode(ambient)
    }
    required init?(coder:NSCoder) { fatalError() }
    func node(_ geometry:SCNGeometry,_ color:UIColor,_ position:SCNVector3) -> SCNNode {
        geometry.firstMaterial?.diffuse.contents = color
        let n = SCNNode(geometry:geometry)
        n.position = position
        return n
    }
    func position(_ p:CGPoint,_ height:Float = 0) -> SCNVector3 {
        SCNVector3(Float(p.x-466)/100,height,Float(365-p.y)/100)
    }
    func fighter(_ color:UIColor) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(node(SCNSphere(radius:0.09),color,SCNVector3(0,0.62,0)))
        root.addChildNode(node(SCNCapsule(capRadius:0.035,height:0.27),color,SCNVector3(0,0.40,0)))
        for side:Float in [-1,1] {
            let leg = node(SCNCapsule(capRadius:0.026,height:0.28),color,SCNVector3(side*0.065,0.15,0))
            leg.eulerAngles.z = side*0.35
            root.addChildNode(leg)
            let arm = node(SCNCapsule(capRadius:0.025,height:0.23),color,SCNVector3(side*0.1,0.4,-0.03))
            arm.eulerAngles.z = side*0.8
            root.addChildNode(arm)
        }
        return root
    }
    func update(_ game:Arena) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        defer { SCNTransaction.commit() }
        if terrainLevel != game.level || terrainWalls != game.walls {
            terrainLevel = game.level
            terrainWalls = game.walls
            terrain.childNodes.forEach { $0.removeFromParentNode() }
            let colors:[UIColor] = [.systemTeal,.systemIndigo,.systemOrange,.systemPurple]
            let color = colors[(game.level-1)%colors.count]
            terrain.addChildNode(node(SCNBox(width:8.8,height:0.16,length:5.5,chamferRadius:0.08),color.darker,SCNVector3(0,-0.08,0)))
            for x in stride(from:-4.0,through:4.0,by:0.5) {
                terrain.addChildNode(node(SCNBox(width:0.012,height:0.005,length:5.4,chamferRadius:0),UIColor(white:1,alpha:0.16),SCNVector3(Float(x),0.005,0)))
            }
            for z in stride(from:-2.5,through:2.5,by:0.5) {
                terrain.addChildNode(node(SCNBox(width:8.7,height:0.005,length:0.012,chamferRadius:0),UIColor(white:1,alpha:0.16),SCNVector3(0,0.005,Float(z))))
            }
            for r in game.walls {
                terrain.addChildNode(node(SCNBox(width:r.width/100,height:0.42,length:r.height/100,chamferRadius:0.04),color.darker,position(CGPoint(x:r.midX,y:r.midY),0.21)))
            }
        }
        // Reuse roots and geometry while updating positions and health each frame.
        let count = 1+game.enemies.count+game.pickups.count+game.shots.count
        while actorPool.count < count {
            let n = SCNNode(); actors.addChildNode(n); actorPool.append(n)
        }
        for n in actorPool { n.isHidden = true }
        var index = 0
        func add(_ child:@autoclosure () -> SCNNode,_ p:CGPoint,_ yaw:Float = 0,_ kind:String) -> SCNNode {
            let n = actorPool[index]; index += 1
            n.isHidden = false
            if n.name != kind {
                n.childNodes.forEach { $0.removeFromParentNode() }
                n.addChildNode(child())
                n.name = kind
            }
            n.position = position(p)
            n.eulerAngles.y = yaw
            return n
        }
        func hero() -> SCNNode {
            let n = fighter(game.lime)
            if game.activeWeapon > 0 {
                let weapon = node(SCNBox(width:game.activeWeapon > 1 ? 0.07 : 0.025,height:0.07,length:game.activeWeapon > 1 ? 0.24 : 0.16,chamferRadius:0.01),game.activeWeapon > 1 ? .darkGray : .lightGray,SCNVector3(0.10,0.4,-0.18))
                n.addChildNode(weapon)
            }
            return n
        }
        let yaw = Float(atan2(game.player.x-game.mouse.x,game.mouse.y-game.player.y))
        let playerNode = add(hero(),game.player,yaw,"hero-\(game.activeWeapon)")
        playerNode.isHidden = game.grace > 0 && Int(game.elapsed*16)%2 != 0
        for e in game.enemies {
            func enemy() -> SCNNode {
                let n = fighter(e.kind == 2 ? .systemPurple : e.kind == 1 ? .systemOrange : .systemRed)
                if e.kind == 2 { n.scale = SCNVector3(1.3,1.3,1.3) }
                let bar = node(SCNBox(width:0.34,height:0.025,length:0.04,chamferRadius:0),.systemRed,SCNVector3(0,0.82,0))
                bar.name = "health"
                n.addChildNode(bar)
                return n
            }
            let n = add(enemy(),e.p,Float(atan2(e.p.x-game.player.x,game.player.y-e.p.y)),"enemy-\(e.kind)")
            n.childNode(withName:"health",recursively:true)?.scale.x = Float(max(0,e.hp/e.maxHP))
        }
        for p in game.pickups {
            func pickup() -> SCNNode {
                let n = SCNNode()
                if p.heart {
                    n.addChildNode(node(SCNSphere(radius:0.075),.systemPink,SCNVector3(-0.052,0.23,0)))
                    n.addChildNode(node(SCNSphere(radius:0.075),.systemPink,SCNVector3(0.052,0.23,0)))
                    n.addChildNode(node(SCNCone(topRadius:0.11,bottomRadius:0,height:0.18),.systemPink,SCNVector3(0,0.13,0)))
                } else {
                    let coin = node(SCNCylinder(radius:0.1,height:0.04),.systemYellow,SCNVector3(0,0.15,0))
                    coin.eulerAngles.x = Float.pi/2
                    n.addChildNode(coin)
                }
                return n
            }
            _ = add(pickup(),p.p,0,p.heart ? "heart" : "coin")
        }
        for s in game.shots {
            func tracer() -> SCNNode {
                let n = node(SCNBox(width:0.065,height:0.065,length:0.22,chamferRadius:0.025),.systemYellow,SCNVector3(0,0.4,0))
                n.geometry?.firstMaterial?.emission.contents = UIColor.systemYellow
                return n
            }
            _ = add(tracer(),s.p,Float(atan2(-s.v.x,s.v.y)),"shot")
        }
    }
}
private extension UIColor {
    var darker:UIColor { var r:CGFloat = 0,g:CGFloat = 0,b:CGFloat = 0,a:CGFloat = 0; getRed(&r,green:&g,blue:&b,alpha:&a); return UIColor(red:r*0.4,green:g*0.4,blue:b*0.4,alpha:1) }
}
final class GameController:UIViewController {
    let game = Arena(frame:.zero)
    let world = ArenaWorld(frame:.zero)
    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
        view.addSubview(world)
        view.addSubview(game)
        game.isOpaque = false
        game.backgroundColor = .clear
        game.world = world
        #if DEBUG
        if CommandLine.arguments.contains("--verify-combat") {
            let test = Arena(frame:.zero)
            test.timer?.invalidate()
            test.start()
            test.mouse = CGPoint(x:700,y:350)
            for weapon in [2,3,4] {
                test.activeWeapon = weapon
                test.shots.removeAll()
                test.attack()
                assert(test.shots.count == (weapon == 3 ? 5 : 1),"Gun must emit projectiles")
                assert(test.shots.allSatisfy { $0.v.x > 0 && $0.damage > 0 },"Bullets must move and deal damage")
            }
            test.activeWeapon = 2
            test.shots.removeAll()
            test.enemies = [Fighter(p:CGPoint(x:560,y:350),hp:100,maxHP:100,kind:0)]
            test.intermission = 100
            test.attack()
            for _ in 0..<5 { test.last = Date(timeIntervalSinceNow:-0.03); test.step() }
            assert(test.enemies.first?.hp == 65,"Pistol projectile must damage the enemy")
            print("COMBAT CHECK PASSED: pistol, shotgun, rifle emit bullets; projectile collision deals damage")
        }
        if CommandLine.arguments.contains("--preview-arena") {
            game.start()
            for _ in 0..<5 { game.spawn() }
            game.pickups = [Pickup(p:CGPoint(x:380,y:400),heart:true,value:25),Pickup(p:CGPoint(x:530,y:290),heart:false,value:3)]
            game.attack()
            for i in game.shots.indices { game.shots[i].p.x += 90 }
            game.timer?.invalidate()
        }
#endif
        world.update(game)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        game.frame = view.bounds
        let a = game.arena, scale = game.displayScale, origin = game.offset
        world.frame = CGRect(x:origin.x+a.minX*scale,y:origin.y+(780-a.maxY)*scale,width:a.width*scale,height:a.height*scale)
    }
    override func viewDidAppear(_ animated:Bool) {
        super.viewDidAppear(animated)
        if game.window?.isKeyWindow == true && !game.isFirstResponder {
            game.becomeFirstResponder()
        }
    }
    override func viewWillDisappear(_ animated:Bool) {
        game.resignFirstResponder()
        game.lostFocus()
        super.viewWillDisappear(animated)
    }
    override var prefersStatusBarHidden:Bool { true }
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override var prefersHomeIndicatorAutoHidden:Bool { true }
}
@main
final class AppDelegate:UIResponder,UIApplicationDelegate {
    func application(_ application:UIApplication,configurationForConnecting connectingSceneSession:UISceneSession,options:UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name:"Game",sessionRole:connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
final class SceneDelegate:UIResponder,UIWindowSceneDelegate {
    var window:UIWindow?
    func scene(_ scene:UIScene,willConnectTo session:UISceneSession,options connectionOptions:UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene:windowScene)
        w.rootViewController = GameController()
        window = w
        w.makeKeyAndVisible()
    }
}
