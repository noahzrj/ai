import SwiftUI
import Combine

struct Upgrade {
    let name: String, symbol: String, description: String
    let base: Double, click: Int, rate: Int
}
struct Save: Codable { var potatoes: Double = 0; var owned = Array(repeating: 0, count: 10) }
final class Patch: ObservableObject {
    static let upgrades = [
        Upgrade(name: "Better trowel", symbol: "leaf.fill", description: "+1 potato per tap", base: 15, click: 1, rate: 0),
        Upgrade(name: "Potato farmer", symbol: "person.fill", description: "+1 potato per second", base: 30, click: 0, rate: 1),
        Upgrade(name: "Harvest basket", symbol: "basket.fill", description: "+5 potatoes per tap", base: 125, click: 5, rate: 0),
        Upgrade(name: "Rolling fields", symbol: "sun.max.fill", description: "+10 potatoes per second", base: 350, click: 0, rate: 10),
        Upgrade(name: "Golden gloves", symbol: "hand.raised.fill", description: "+25 potatoes per tap", base: 1200, click: 25, rate: 0),
        Upgrade(name: "Greenhouse", symbol: "house.fill", description: "+50 potatoes per second", base: 2500, click: 0, rate: 50),
        Upgrade(name: "Super spade", symbol: "bolt.fill", description: "+100 potatoes per tap", base: 7000, click: 100, rate: 0),
        Upgrade(name: "Spud factory", symbol: "building.2.fill", description: "+250 potatoes per second", base: 15000, click: 0, rate: 250),
        Upgrade(name: "Potato wizard", symbol: "sparkles", description: "+500 potatoes per tap", base: 40000, click: 500, rate: 0),
        Upgrade(name: "Moon farm", symbol: "moon.stars.fill", description: "+1500 potatoes per second", base: 100000, click: 0, rate: 1500)
    ]
    @Published var save = Save()
    private let key = "potato.patch.save.v1"
    private var last = ProcessInfo.processInfo.systemUptime
    private var active = true
    var perTap: Int { 1 + Self.upgrades.indices.reduce(0) { $0 + Self.upgrades[$1].click * save.owned[$1] } }
    var perSecond: Int { Self.upgrades.indices.reduce(0) { $0 + Self.upgrades[$1].rate * save.owned[$1] } }
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let loaded = try? JSONDecoder().decode(Save.self, from: data), loaded.potatoes.isFinite, loaded.potatoes >= 0, (loaded.owned.count == 4 || loaded.owned.count == Self.upgrades.count), loaded.owned.allSatisfy({ $0 >= 0 && $0 <= 10000 }) { save = loaded; save.owned += Array(repeating: 0, count: Self.upgrades.count - loaded.owned.count) }
    }
    func price(_ i: Int) -> Double { ceil(Self.upgrades[i].base * pow(1.18, Double(save.owned[i]))) }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if active { save.potatoes += Double(perSecond) * max(0, now - last) }
        last = now
    }
    func tap() { tick(); save.potatoes += Double(perTap); persist() }
    func buy(_ i: Int) {
        tick(); let cost = price(i)
        guard cost.isFinite, save.potatoes >= cost else { return }
        save.potatoes -= cost; save.owned[i] += 1; persist()
    }
    func setActive(_ value: Bool) { tick(); active = value; persist() }
    func persist() { if let data = try? JSONEncoder().encode(save) { UserDefaults.standard.set(data, forKey: key) } }
    func reset() { save = Save(); last = ProcessInfo.processInfo.systemUptime; persist() }
}

struct PotatoArt: View {
    var body: some View {
        Canvas { context, size in
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }
            var skin = Path()
            skin.move(to: pt(0.51, 0.09))
            skin.addCurve(to: pt(0.84, 0.40), control1: pt(0.83, 0.02), control2: pt(0.80, 0.20))
            skin.addCurve(to: pt(0.79, 0.83), control1: pt(1.0, 0.64), control2: pt(0.94, 0.73))
            skin.addCurve(to: pt(0.18, 0.80), control1: pt(0.61, 1.02), control2: pt(0.27, 0.96))
            skin.addCurve(to: pt(0.24, 0.28), control1: pt(0.01, 0.60), control2: pt(0.19, 0.42))
            skin.addCurve(to: pt(0.51, 0.09), control1: pt(0.26, 0.11), control2: pt(0.39, 0.06))
            context.fill(skin, with: .linearGradient(Gradient(colors: [Color(red: 0.94, green: 0.78, blue: 0.54), Color(red: 0.66, green: 0.45, blue: 0.24)]), startPoint: .zero, endPoint: pt(1, 1)))
            context.stroke(skin, with: .color(.brown.opacity(0.5)), lineWidth: 2)
            for (x, y) in [(0.32,0.30),(0.67,0.24),(0.74,0.70),(0.28,0.74),(0.53,0.84)] {
                context.fill(Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: 7, height: 4)), with: .color(.brown.opacity(0.6)))
            }
            for x in [0.42, 0.61] {
                context.fill(Path(ellipseIn: CGRect(x: x * size.width, y: 0.51 * size.height, width: 9, height: 11)), with: .color(Color(red: 0.26, green: 0.20, blue: 0.13)))
            }
            var smile = Path(); smile.move(to: pt(0.48, 0.61)); smile.addQuadCurve(to: pt(0.59, 0.61), control: pt(0.535, 0.70))
            context.stroke(smile, with: .color(.brown), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
}

struct HarvestEffect: Identifiable {
    let id = UUID()
    let amount: Int
    let start = Date()
}
struct HarvestParticles: View {
    let effects: [HarvestEffect]
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for effect in effects {
                    let t = timeline.date.timeIntervalSince(effect.start)
                    guard t >= 0 && t < 0.85 else { continue }
                    context.opacity = 1 - t / 0.85
                    context.draw(Text("+\(effect.amount)").font(.title2.bold()).foregroundStyle(.green), at: CGPoint(x: size.width / 2, y: 90 - t * 100))
                    for i in 0..<10 {
                        let angle = Double(i) * .pi / 5
                        let distance = t * 140
                        let point = CGPoint(x: size.width / 2 + cos(angle) * distance, y: size.height / 2 + sin(angle) * distance + t * t * 50)
                        context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 6, height: 6)), with: .color(i.isMultiple(of: 2) ? .yellow : .green))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct PatchView: View {
    @StateObject private var patch = Patch()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var resetAlert = false
    @State private var bounce = false
    @State private var effects: [HarvestEffect] = []
    @State private var celebration = ""
    @State private var feedback = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let saver = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private let green = Color(red: 0.26, green: 0.40, blue: 0.26)
    private func number(_ n: Double) -> String { n.formatted(.number.precision(.fractionLength(0)).rounded(rule: .down)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("🥔 potatopatch.").font(.title2.bold()); Spacer(); Image(systemName: "leaf").foregroundStyle(green) }
                VStack(alignment: .leading, spacing: 8) {
                    Text("SMALL SPUD. BIG DREAMS.").font(.caption.bold()).tracking(2).foregroundStyle(green)
                    Text("Good things take spuds.").font(.system(size: 36, design: .serif))
                    Text("Tap a potato. Grow your patch.").foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    Text("YOUR HARVEST").font(.caption.bold()).tracking(2).foregroundStyle(green)
                    Text(number(patch.save.potatoes)).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.4).lineLimit(1)
                        .accessibilityLabel("\(number(patch.save.potatoes)) potatoes")
                    Text("potatoes").foregroundStyle(.secondary)
                    Button {
                        let amount = patch.perTap
                        patch.tap()
                        if !reduceMotion {
                            effects = Array((effects + [HarvestEffect(amount: amount)]).suffix(12))
                            bounce = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { bounce = false } }
                        }
                    } label: { PotatoArt().frame(width: 215, height: 220).scaleEffect(bounce ? 0.90 : 1).rotationEffect(.degrees(bounce ? -5 : 0)).shadow(color: .brown.opacity(0.16), radius: 12, y: 12).overlay { if !reduceMotion && !effects.isEmpty { HarvestParticles(effects: effects) } } }
                    .buttonStyle(.plain).accessibilityLabel("Harvest potato").accessibilityHint("Adds \(patch.perTap) potatoes")
                    Text("Give your spud a tap").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) { stat(patch.perTap, "per tap"); stat(patch.perSecond, "per second") }.padding(.top, 12)
                }.padding(24).frame(maxWidth: .infinity).background(Color(red: 0.91, green: 0.94, blue: 0.87), in: RoundedRectangle(cornerRadius: 24))
                Text("Grow your patch").font(.system(size: 27, design: .serif))
                ForEach(Patch.upgrades.indices, id: \.self) { i in
                    let u = Patch.upgrades[i]; let cost = patch.price(i)
                    HStack(spacing: 12) {
                        Image(systemName: u.symbol).font(.title3).foregroundStyle(green).frame(width: 40, height: 48).background(green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(u.name).font(.headline)
                            Text(u.description).font(.caption).foregroundStyle(.secondary)
                            Text("Owned: \(patch.save.owned[i])").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button { patch.buy(i); celebration = "✨ \(u.name) added!"; feedback += 1 } label: { Text(cost.isFinite ? "🥔 \(number(cost))" : "Maxed").font(.caption.bold()).padding(.vertical, 14).padding(.horizontal, 10) }
                            .buttonStyle(.borderedProminent).tint(green).disabled(!cost.isFinite || patch.save.potatoes < cost)
                            .accessibilityLabel("Buy \(u.name) for \(number(cost)) potatoes")
                    }.padding(14).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                }
                if !celebration.isEmpty { Text(celebration).font(.callout.bold()).foregroundStyle(green).accessibilityAddTraits(.updatesFrequently) }
                Text("Farmers and fields harvest automatically while the app is active. Your progress saves on this iPhone.").font(.caption).foregroundStyle(.secondary)
                Button("Start a fresh patch") { resetAlert = true }.font(.caption).tint(.secondary).frame(maxWidth: .infinity).padding(.vertical)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.background(Color(red: 0.97, green: 0.96, blue: 0.93)).foregroundStyle(Color(red: 0.19, green: 0.23, blue: 0.16))
        .sensoryFeedback(.success, trigger: feedback)
        .onReceive(timer) { _ in patch.tick(); effects.removeAll { Date().timeIntervalSince($0.start) > 0.85 } }.onReceive(saver) { _ in patch.persist() }
        .onChange(of: phase) { _, value in patch.setActive(value == .active) }
        .alert("Start a fresh patch?", isPresented: $resetAlert) { Button("Cancel", role: .cancel) {}; Button("Reset", role: .destructive) { patch.reset() } } message: { Text("This erases all your potatoes and upgrades.") }
    }
    private func stat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 4) { Text(value.formatted()).font(.title2.bold()); Text(title.uppercased()).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(14).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}
@main struct PotatoPatchApp: App { var body: some Scene { WindowGroup { PatchView().preferredColorScheme(.light) } } }
