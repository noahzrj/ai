import Cocoa

struct Fighter { var p: CGPoint; var hp: Double; var maxHP: Double; var kind: Int }
struct Pickup { var p: CGPoint; var heart: Bool; var value: Int }
struct Shot { var p: CGPoint; var v: CGPoint; var life: Double; var damage: Double }
struct Weapon { let name: String; let damage: Double; let rate: Double; let range: Double; let speed: Double }
final class Arena: NSView {
    let lime = NSColor(calibratedRed: 0.82, green: 1, blue: 0.42, alpha: 1)
    let weapons = [Weapon(name:"Bare hands",damage:24,rate:0.30,range:72,speed:0), Weapon(name:"Combat knife",damage:45,rate:0.23,range:96,speed:0), Weapon(name:"Pistol",damage:35,rate:0.28,range:850,speed:700), Weapon(name:"Shotgun",damage:25,rate:0.6,range:350,speed:550), Weapon(name:"Assault rifle",damage:29,rate:0.11,range:1000,speed:850)]
    var mode = "menu", previous = "menu", keys = Set<UInt16>(), mouse = CGPoint(x:650,y:350), firing = false
    var player = CGPoint(x:470,y:330), hp = 100.0, enemies = [Fighter](), pickups = [Pickup](), shots = [Shot](), walls = [CGRect]()
    var level = 1, unlocked = 1, wave = 1, remaining = 0, coins = 0, owned = [0], equipped = 0, activeWeapon = 0
    var cooldown = 0.0, grace = 0.0, spawnClock = 0.0, intermission = 0.0, elapsed = 0.0, earned = 0, kills = 0, won = false
    var message = "", swing = 0.0, buttons = [(CGRect,String)](), timer: Timer?, last = Date()
    let arena = CGRect(x:26,y:90,width:880,height:550)
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame:frame)
        let d = UserDefaults.standard
        coins = max(0,d.integer(forKey:"coins")); unlocked = max(1,d.integer(forKey:"unlocked")); owned = (d.array(forKey:"owned") as? [Int] ?? [0]).filter { (0...4).contains($0) }; if !owned.contains(0) { owned.append(0) }
        equipped = d.integer(forKey:"equipped"); if !owned.contains(equipped) { equipped = 0 }
        timer = Timer.scheduledTimer(withTimeInterval:1.0/60, repeats:true) { [weak self] _ in self?.step() }
        NotificationCenter.default.addObserver(self,selector:#selector(lostFocus),name:NSWindow.didResignKeyNotification,object:nil)
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc func lostFocus() { keys.removeAll(); firing = false; if mode == "play" { mode = "pause" }; needsDisplay = true }
    func save() { let d = UserDefaults.standard; d.set(coins,forKey:"coins"); d.set(unlocked,forKey:"unlocked"); d.set(owned,forKey:"owned"); d.set(equipped,forKey:"equipped") }
    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat = 14,_ color:NSColor = .white,_ bold:Bool = false) {
        let font = bold ? NSFont.boldSystemFont(ofSize:size) : NSFont.systemFont(ofSize:size)
        s.draw(at:CGPoint(x:x,y:y),withAttributes:[.font:font,.foregroundColor:color])
    }
    func fill(_ r:CGRect,_ c:NSColor,_ radius:CGFloat = 0) { c.setFill(); NSBezierPath(roundedRect:r,xRadius:radius,yRadius:radius).fill() }
    func line(_ a:CGPoint,_ b:CGPoint,_ c:NSColor,_ width:CGFloat = 3) { c.setStroke(); let p = NSBezierPath(); p.lineWidth = width; p.lineCapStyle = .round; p.move(to:a); p.line(to:b); p.stroke() }
    func button(_ title:String,_ rect:CGRect,_ action:String,_ primary:Bool = false) { fill(rect,primary ? lime : NSColor(white:0.20,alpha:1),8); text(title,rect.minX+14,rect.minY+12,14,primary ? .black : .white,true); buttons.append((rect,action)) }
    override func draw(_ dirtyRect:NSRect) {
        buttons.removeAll()
        fill(bounds,NSColor(calibratedRed:0.06,green:0.09,blue:0.075,alpha:1))
        text("STICK & SURVIVE",26,720,28,lime,true); text("NATIVE MACOS • ARENA SURVIVAL",760,730,11,.lightGray)
        text("STAND YOUR GROUND.",26,670,34,.white,true)
        let palettes = [NSColor(calibratedRed:0.10,green:0.16,blue:0.12,alpha:1),NSColor(calibratedRed:0.11,green:0.14,blue:0.20,alpha:1),NSColor(calibratedRed:0.19,green:0.14,blue:0.10,alpha:1),NSColor(calibratedRed:0.16,green:0.11,blue:0.19,alpha:1)]
        fill(arena,palettes[(level-1)%4],12)
        for x in stride(from:arena.minX+20,to:arena.maxX,by:40) { line(CGPoint(x:x,y:arena.minY),CGPoint(x:x,y:arena.maxY),NSColor(white:1,alpha:0.035),1) }
        for y in stride(from:arena.minY+20,to:arena.maxY,by:40) { line(CGPoint(x:arena.minX,y:y),CGPoint(x:arena.maxX,y:y),NSColor(white:1,alpha:0.035),1) }
        text(String(format:"%02d",level),400,300,110,NSColor(white:1,alpha:0.045),true)
        for r in walls { fill(r,NSColor(calibratedRed:0.23,green:0.29,blue:0.24,alpha:1),4) }
        for d in pickups { text(d.heart ? "♥" : "●",d.p.x-8,d.p.y-10,22,d.heart ? .systemPink : .systemYellow,true) }
        for e in enemies { stick(e.p,e.kind == 2 ? .systemPurple : e.kind == 1 ? .systemOrange : .systemRed,e.kind == 2 ? 1.25 : 1); fill(CGRect(x:e.p.x-17,y:e.p.y+33,width:34,height:3),.darkGray); fill(CGRect(x:e.p.x-17,y:e.p.y+33,width:34*max(0,e.hp/e.maxHP),height:3),.systemRed) }
        if grace <= 0 || Int(elapsed*16)%2 == 0 { stick(player,lime,1) }
        let aim = atan2(mouse.y-player.y,mouse.x-player.x)
        line(player,CGPoint(x:player.x+cos(aim)*25,y:player.y+sin(aim)*25),lime,activeWeapon > 1 ? 5 : 3)
        if swing > 0 { lime.withAlphaComponent(0.35).setStroke(); let p = NSBezierPath(); p.lineWidth = 7; p.appendArc(withCenter:player,radius:weapons[activeWeapon].range,startAngle:(aim-1)*180 / .pi,endAngle:(aim+1)*180 / .pi); p.stroke() }
        for b in shots { fill(CGRect(x:b.p.x-3,y:b.p.y-3,width:6,height:6),lime,3) }
        text("HEALTH  \(Int(ceil(hp)))",46,607,12,.white,true); fill(CGRect(x:46,y:593,width:160,height:6),.darkGray,3); fill(CGRect(x:46,y:593,width:160*hp/100,height:6),lime,3)
        text("LEVEL \(level)     WAVE \(wave) / 10",690,607,12,.white,true)
        if mode == "play" && intermission > 0 { text("WAVE \(wave)",405,540,30,lime,true) }
        fill(CGRect(x:926,y:90,width:248,height:550),NSColor(white:0.11,alpha:1),12)
        text("YOUR WALLET",946,605,11,.lightGray,true); text("● \(coins)",946,559,32,lime,true)
        text("LOADOUT",946,510,11,.lightGray,true); text(weapons[equipped].name,946,477,20,.white,true)
        if mode != "play" && mode != "pause" { button("Change weapon",CGRect(x:946,y:419,width:207,height:42),"weapon"); button("Level \(level)  →",CGRect(x:946,y:364,width:207,height:42),"level") }
        text("FIELD GUIDE",946,324,11,.lightGray,true)
        for (i,s) in ["W A S D       Move","Mouse         Aim","Click / Space  Attack","Arrow keys    Aim","P / Escape    Pause","♥  Recover 25 health","●  Coins fund loot boxes"].enumerated() { text(s,946,294-CGFloat(i)*25,12,.lightGray) }
        text("KEEP MOVING. KEEP FIGHTING.",26,52,11,.lightGray); text("Progress saved on this Mac",941,52,11,.lightGray)
        if mode != "play" {
            fill(arena,NSColor(white:0.035,alpha:0.92),12)
            if mode == "shop" {
                text("THE SUPPLY ROOM",300,553,12,lime,true); text("A little luck. More firepower.",215,497,30,.white,true)
                text("Weapons stay in your arsenal. Duplicates refund half the price.",225,457,13,.lightGray)
                fill(CGRect(x:165,y:257,width:280,height:163),NSColor(white:0.14,alpha:1),10)
                fill(CGRect(x:475,y:257,width:280,height:163),NSColor(white:0.14,alpha:1),10)
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
                else { text("Survive 10 waves. Collect hearts and coins. Build your arsenal.",225,379,15,.lightGray); text("WASD to move · Mouse to aim · Click or Space to attack",250,345,14,.lightGray) }
                button(mode == "end" ? (won ? "Next level →" : "Try again →") : "Enter the arena →",CGRect(x:240,y:255,width:230,height:48),"start",true)
                button("Visit shop",CGRect(x:490,y:255,width:170,height:48),"shop")
            }
        }
    }
    func stick(_ p:CGPoint,_ c:NSColor,_ scale:CGFloat) {
        c.setStroke(); let head = NSBezierPath(ovalIn:CGRect(x:p.x-7*scale,y:p.y+10*scale,width:14*scale,height:14*scale)); head.lineWidth = 3; head.stroke()
        let gait = mode == "play" ? sin(elapsed*10)*4 : 0
        line(CGPoint(x:p.x,y:p.y+10),CGPoint(x:p.x,y:p.y-9),c)
        line(CGPoint(x:p.x,y:p.y-9),CGPoint(x:p.x-9-gait,y:p.y-24*scale),c)
        line(CGPoint(x:p.x,y:p.y-9),CGPoint(x:p.x+9+gait,y:p.y-24*scale),c)
        line(CGPoint(x:p.x,y:p.y+5),CGPoint(x:p.x-12*scale,y:p.y-5),c)
        line(CGPoint(x:p.x,y:p.y+5),CGPoint(x:p.x+12*scale,y:p.y-5),c)
    }
    func start() {
        mode = "play"; hp = 100; player = CGPoint(x:466,y:350); enemies = []; pickups = []; shots = []; earned = 0; kills = 0; wave = 1; activeWeapon = equipped; cooldown = 0; grace = 0; keys.removeAll(); firing = false
        let patterns:[[CGRect]] = [[CGRect(x:220,y:220,width:120,height:35),CGRect(x:590,y:465,width:120,height:35)],[CGRect(x:240,y:210,width:45,height:150),CGRect(x:650,y:390,width:45,height:150)],[CGRect(x:200,y:210,width:95,height:50),CGRect(x:630,y:210,width:95,height:50),CGRect(x:200,y:470,width:95,height:50),CGRect(x:630,y:470,width:95,height:50)],[CGRect(x:170,y:230,width:190,height:32),CGRect(x:550,y:450,width:190,height:32)]]
        walls = patterns[(level-1)%4]; beginWave()
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
        guard mode == "play" else { needsDisplay = true; return }
        elapsed += dt; cooldown -= dt; grace -= dt; swing -= dt
        let dx = (keys.contains(2) ? 1.0 : 0)-(keys.contains(0) ? 1.0 : 0), dy = (keys.contains(13) ? 1.0 : 0)-(keys.contains(1) ? 1.0 : 0), n = max(1,hypot(dx,dy))
        move(&player,dx/n*215*dt,dy/n*215*dt)
        let ax = (keys.contains(124) ? 1.0 : 0)-(keys.contains(123) ? 1.0 : 0), ay = (keys.contains(126) ? 1.0 : 0)-(keys.contains(125) ? 1.0 : 0)
        if ax != 0 || ay != 0 { mouse = CGPoint(x:player.x+ax*100,y:player.y+ay*100) }
        if (firing || keys.contains(49)) && cooldown <= 0 { attack() }
        if intermission > 0 { intermission -= dt } else if remaining > 0 { spawnClock -= dt; if spawnClock <= 0 { spawn(); remaining -= 1; spawnClock = max(0.15,0.8-Double(wave)*0.035-Double(level)*0.025) } }
        for i in enemies.indices where enemies[i].hp > 0 {
            let a = atan2(player.y-enemies[i].p.y,player.x-enemies[i].p.x), speed = (enemies[i].kind == 2 ? 48.0 : enemies[i].kind == 1 ? 130.0 : 78.0)*(1+Double(min(level-1,30))*0.055)
            var p = enemies[i].p; let old = p; move(&p,cos(a)*speed*dt,sin(a)*speed*dt)
            if distance(old,p) < 0.1 { move(&p,cos(a+1.3)*speed*dt,sin(a+1.3)*speed*dt) }; enemies[i].p = p
            if distance(p,player) < 29 && grace <= 0 { hp = max(0,hp-Double(enemies[i].kind == 2 ? 22 : 10+min(level,25))); grace = 0.7; if hp <= 0 { end(false); needsDisplay = true; return } }
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
        needsDisplay = true
    }
    func openCrate(_ elite:Bool) {
        let cost = elite ? 100 : 40; guard coins >= cost else { message = "You need \(cost-coins) more coins for this crate."; return }
        coins -= cost; let r = Double.random(in:0...1); let item = elite ? (r < 0.3 ? 2 : r < 0.7 ? 3 : 4) : (r < 0.5 ? 1 : r < 0.85 ? 2 : 3)
        if owned.contains(item) { coins += cost/2; message = "Duplicate \(weapons[item].name). \(cost/2) coins returned." } else { owned.append(item); equipped = item; message = "Unlocked \(weapons[item].name)! Equipped for your next run." }; save()
    }
    override func mouseDown(with event:NSEvent) {
        window?.makeFirstResponder(self); let p = convert(event.locationInWindow,from:nil)
        if mode == "play" { mouse = p; firing = true; return }
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
        default: break
        }; needsDisplay = true
    }
    override func mouseUp(with event:NSEvent) { firing = false }
    override func mouseMoved(with event:NSEvent) { mouse = convert(event.locationInWindow,from:nil) }
    override func mouseDragged(with event:NSEvent) { mouseMoved(with:event) }
    override func keyDown(with event:NSEvent) {
        if (event.keyCode == 35 || event.keyCode == 53) && !event.isARepeat { if mode == "play" { mode = "pause"; firing = false } else if mode == "pause" { mode = "play" }; needsDisplay = true; return }
        if mode == "play" { keys.insert(event.keyCode) }
    }
    override func keyUp(with event:NSEvent) { keys.remove(event.keyCode) }
}
final class AppDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    func applicationDidFinishLaunching(_ notification:Notification) {
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:1200,height:780),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Stick & Survive"; window.center(); window.acceptsMouseMovedEvents = true
        let view = Arena(frame:NSRect(x:0,y:0,width:1200,height:780)); window.contentView = view; window.makeFirstResponder(view)
        let main = NSMenu(), item = NSMenuItem(), appMenu = NSMenu(); appMenu.addItem(withTitle:"Quit Stick & Survive",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); item.submenu = appMenu; main.addItem(item); NSApp.mainMenu = main
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool { true }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
