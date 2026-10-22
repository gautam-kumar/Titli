import SceneKit
import UIKit
import TitliCore

// The live hero: a 3D titli whose aurora flight trail carries your latest memories as pearls.
// A SceneKit port of the web hero (hero.js), keeping its shapes, colours and timings.

enum HeroMode: Equatable { case home, listen, answer }

let kindColor: [Memory.Kind: UIColor] = [
    .give: UIColor(hex: 0xFF4FA3), .take: UIColor(hex: 0x00C2FF), .doc: UIColor(hex: 0x7B61FF),
    .remind: UIColor(hex: 0xFFB547), .note: UIColor(hex: 0x9D8BFF),
]
private let stops = [0x00C2FF, 0x7B61FF, 0xFF4FA3, 0xFFB547].map { SIMD3<Float>(UIColor(hex: $0).rgb) }

final class HeroScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    private let camera = SCNNode()
    private let butterfly = SCNNode()
    private var wingR = SCNNode(), wingL = SCNNode()
    private var ribbons: [SCNNode] = []
    private let pearlRoot = SCNNode()
    private var pearls: [(node: SCNNode, t: Float)] = []
    private var big: SCNNode?
    private let path: Curve
    private(set) var mode: HeroMode = .home
    private var aspect: Float = 1.3
    private var start: TimeInterval?
    /// Screen points of the two newest pearls, for the SwiftUI tags.
    var onTags: (([CGPoint]) -> Void)?
    private var frameCount = 0
    /// SceneKit calls the renderer delegate on its own thread; state changes from SwiftUI take this lock.
    private let lock = NSLock()

    override init() {
        path = Curve([[-2.5, -0.9, 0.4], [-1.8, 0.1, 0.7], [-1.0, -0.7, 1.0], [-0.2, -0.8, 0.8], [0.2, -0.35, 0.3], [0.2, 0.08, 0]].map { SIMD3<Float>($0[0], $0[1], $0[2]) })
        super.init()
        build()
    }

    // MARK: building

    private func build() {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = Self.environmentImage()
        scene.lightingEnvironment.intensity = 1.1

        let cam = SCNCamera()
        cam.fieldOfView = 30
        cam.zNear = 0.1; cam.zFar = 100
        camera.camera = cam
        scene.rootNode.addChildNode(camera)

        let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional; key.light!.intensity = 1300
        key.simdPosition = [-3, 5, 4]; key.simdLook(at: .zero); scene.rootNode.addChildNode(key)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light!.type = .directional; rim.light!.intensity = 800
        rim.light!.color = UIColor(hex: 0xFFC6EF); rim.simdPosition = [3, 1, -3]; rim.simdLook(at: .zero); scene.rootNode.addChildNode(rim)
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 300
        amb.light!.color = UIColor(hex: 0xE9E1FF); scene.rootNode.addChildNode(amb)

        buildButterfly()
        let params: [(Float, Float, Float, Float)] = [(0, 0.9, 0.9, 0.6), (1.5, 0.6, 1.1, 0.5), (2.9, 0.4, 0.7, 0.6), (4.1, 1.3, 0.5, 0.16)]
        for p in params {
            let r = ribbon(off: p.0, width: p.1, twist: p.2, op: p.3)
            ribbons.append(r); scene.rootNode.addChildNode(r)
        }
        let shadow = SCNNode(geometry: SCNPlane(width: 2.2, height: 2.2))
        shadow.geometry!.firstMaterial = Self.flat(Self.blob(rgb: (70, 40, 140), alpha: 0.22))
        shadow.eulerAngles.x = -.pi / 2; shadow.position.y = -1.25
        scene.rootNode.addChildNode(shadow)
        scene.rootNode.addChildNode(pearlRoot)
    }

    private func buildButterfly() {
        let x0: CGFloat = -0.05, x1: CGFloat = 1.4, y0: CGFloat = -1.05, y1: CGFloat = 1.1
        let fore = UIBezierPath(); fore.move(to: .init(x: 0.04, y: 0.06))
        fore.addCurve(to: .init(x: 1.12, y: 0.98), controlPoint1: .init(x: 0.25, y: 0.55), controlPoint2: .init(x: 0.7, y: 1.02))
        fore.addCurve(to: .init(x: 1.22, y: 0.5), controlPoint1: .init(x: 1.32, y: 0.95), controlPoint2: .init(x: 1.36, y: 0.7))
        fore.addCurve(to: .init(x: 0.06, y: -0.04), controlPoint1: .init(x: 1.0, y: 0.2), controlPoint2: .init(x: 0.55, y: 0.02))
        fore.close()
        let hind = UIBezierPath(); hind.move(to: .init(x: 0.05, y: -0.02))
        hind.addCurve(to: .init(x: 0.95, y: -0.42), controlPoint1: .init(x: 0.5, y: 0.02), controlPoint2: .init(x: 0.92, y: -0.12))
        hind.addCurve(to: .init(x: 0.48, y: -0.95), controlPoint1: .init(x: 0.98, y: -0.72), controlPoint2: .init(x: 0.75, y: -0.98))
        hind.addCurve(to: .init(x: 0.17, y: -0.62), controlPoint1: .init(x: 0.3, y: -0.93), controlPoint2: .init(x: 0.22, y: -0.8))
        hind.addCurve(to: .init(x: 0.04, y: -0.08), controlPoint1: .init(x: 0.12, y: -0.42), controlPoint2: .init(x: 0.06, y: -0.22))
        hind.close()

        // wing texture, drawn like the web canvas
        let w: CGFloat = 1024, h: CGFloat = 1536
        let sx: CGFloat = w / (x1 - x0), sy: CGFloat = h / (y1 - y0)
        let toPx = CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: -x0 * sx, ty: y1 * sy)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let tex = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            let g = ctx.cgContext, space = CGColorSpaceCreateDeviceRGB()
            let root = CGPoint(x: 0, y: 0).applying(toPx)
            func draw(_ shape: UIBezierPath, _ st: [(CGFloat, Int)]) {
                let p = shape.copy() as! UIBezierPath; p.apply(toPx)
                g.saveGState(); p.addClip()
                let rad = CGGradient(colorsSpace: space, colors: st.map { UIColor(hex: $0.1).cgColor } as CFArray, locations: st.map { $0.0 })!
                g.drawRadialGradient(rad, startCenter: root, startRadius: 10, endCenter: root, endRadius: w, options: [.drawsAfterEndLocation])
                let sheen = CGGradient(colorsSpace: space, colors: [UIColor(hex: 0x00C2FF, a: 0), UIColor(hex: 0x00C2FF, a: 0.28), UIColor(white: 1, alpha: 0.18), UIColor(hex: 0xFFB547, a: 0)].map(\.cgColor) as CFArray, locations: [0, 0.45, 0.6, 1])!
                g.drawLinearGradient(sheen, start: .zero, end: CGPoint(x: w, y: h), options: [])
                g.setStrokeColor(UIColor(red: 40 / 255, green: 20 / 255, blue: 90 / 255, alpha: 0.35).cgColor); g.setLineWidth(3)
                for k in 0..<7 {
                    let a = -1.1 + CGFloat(k) * 0.36
                    g.move(to: root)
                    g.addQuadCurve(to: CGPoint(x: root.x + cos(a) * w * 1.2, y: root.y - sin(a) * h * 0.9), control: CGPoint(x: root.x + cos(a) * w * 0.35, y: root.y - sin(a) * h * 0.25))
                    g.strokePath()
                }
                g.restoreGState()
                p.lineWidth = 26; UIColor(red: 30 / 255, green: 16 / 255, blue: 60 / 255, alpha: 0.9).setStroke(); p.stroke()
                p.lineWidth = 6; UIColor(white: 1, alpha: 0.5).setStroke(); p.stroke()
            }
            draw(fore, [(0, 0x3B1FA8), (0.25, 0x7B61FF), (0.55, 0xFF4FA3), (0.85, 0xFFB547), (1, 0xFFD27A)])
            draw(hind, [(0, 0x3B1FA8), (0.25, 0x5B6BFF), (0.5, 0x00C2FF), (0.8, 0xFF4FA3), (1, 0xFFB547)])
            UIColor(white: 1, alpha: 0.9).setFill()
            for (a, b, r) in [(1.12, 0.82, 0.035), (1.02, 0.9, 0.025), (1.2, 0.66, 0.028), (0.8, -0.78, 0.03)] as [(CGFloat, CGFloat, CGFloat)] {
                let c = CGPoint(x: a, y: b).applying(toPx), rr = r * w / (x1 - x0)
                g.fillEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
            }
        }
        let wingMat = SCNMaterial()
        wingMat.lightingModel = .physicallyBased
        wingMat.diffuse.contents = tex
        wingMat.roughness.contents = 0.35
        wingMat.metalness.contents = 0.05
        wingMat.clearCoat.contents = 0.7
        wingMat.clearCoatRoughness.contents = 0.2
        wingMat.isDoubleSided = true
        wingMat.blendMode = .alpha
        wingMat.writesToDepthBuffer = false

        func wing(_ shape: UIBezierPath) -> SCNGeometry {
            let outline = Self.sample(shape)
            let c = outline.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let center = CGPoint(x: c.x / CGFloat(outline.count), y: c.y / CGFloat(outline.count))
            let rings: [CGFloat] = [0.2, 0.4, 0.6, 0.8, 1.0]
            var pos: [SCNVector3] = [], nrm: [SCNVector3] = [], uv: [CGPoint] = [], idx: [Int32] = []
            func add(_ p: CGPoint) {
                let a = Float(p.x), b = Float(p.y), z = 0.12 * a * a - 0.04 * b * b
                pos.append(SCNVector3(a, b, z))
                nrm.append(SCNVector3(simd_normalize(SIMD3<Float>(-0.24 * a, 0.08 * b, 1))))
                uv.append(CGPoint(x: (p.x - x0) / (x1 - x0), y: (y1 - p.y) / (y1 - y0)))
            }
            add(center)
            for f in rings { for p in outline { add(CGPoint(x: center.x + (p.x - center.x) * f, y: center.y + (p.y - center.y) * f)) } }
            let n = Int32(outline.count)
            for k in 0..<n { idx += [0, 1 + k, 1 + (k + 1) % n] }
            for r in 0..<Int32(rings.count - 1) {
                let a0 = 1 + r * n, b0 = 1 + (r + 1) * n
                for k in 0..<n { let k1 = (k + 1) % n; idx += [a0 + k, b0 + k, b0 + k1, a0 + k, b0 + k1, a0 + k1] }
            }
            let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nrm), SCNGeometrySource(textureCoordinates: uv)],
                                elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
            g.firstMaterial = wingMat
            return g
        }
        func half() -> SCNNode {
            let node = SCNNode()
            node.addChildNode(SCNNode(geometry: wing(fore)))
            let hn = SCNNode(geometry: wing(hind)); hn.position.z = -0.01; node.addChildNode(hn)
            return node
        }
        wingR = half(); wingL = half(); wingL.scale.x = -1
        butterfly.addChildNode(wingR); butterfly.addChildNode(wingL)

        let dark = SCNMaterial()
        dark.lightingModel = .physicallyBased
        dark.diffuse.contents = UIColor(hex: 0x1B1233)
        dark.roughness.contents = 0.3
        dark.clearCoat.contents = 1.0
        let abdomen = SCNNode(geometry: SCNCapsule(capRadius: 0.048, height: 0.82)); abdomen.position.y = -0.2
        let thorax = SCNNode(geometry: SCNSphere(radius: 0.062)); thorax.position.y = 0.15; thorax.scale = SCNVector3(1, 1.4, 1)
        let head = SCNNode(geometry: SCNSphere(radius: 0.06)); head.position.y = 0.3
        for n in [abdomen, thorax, head] { n.geometry!.firstMaterial = dark; butterfly.addChildNode(n) }
        for sx: Float in [1, -1] {
            let pts: [SIMD3<Float>] = (0...8).map { i in
                let t: Float = Float(i) / 8, u: Float = 1 - t
                let a = SIMD3<Float>(sx * 0.02, 0.3, 0), b = SIMD3<Float>(sx * 0.12, 0.6, 0.05), c = SIMD3<Float>(sx * 0.28, 0.85, 0.08)
                let wa: Float = u * u, wb: Float = 2 * u * t, wc: Float = t * t
                return wa * a + wb * b + wc * c
            }
            for i in 0..<8 { butterfly.addChildNode(Self.segment(pts[i], pts[i + 1], 0.009, dark)) }
            let tip = SCNNode(geometry: SCNSphere(radius: 0.03)); tip.geometry!.firstMaterial = dark; tip.simdPosition = pts[8]
            butterfly.addChildNode(tip)
        }
        butterfly.simdOrientation = simd_quatf(angle: 0.55, axis: [1, 0, 0]) * simd_quatf(angle: 0.3, axis: [0, 1, 0]) * simd_quatf(angle: -0.42, axis: [0, 0, 1])
        butterfly.scale = SCNVector3(0.7, 0.7, 0.7)
        butterfly.position = SCNVector3(0.12, 0.18, 0)
        scene.rootNode.addChildNode(butterfly)
    }

    private func ribbon(off: Float, width: Float, twist: Float, op: Float) -> SCNNode {
        let n = 240, m = 18, up = SIMD3<Float>(0, 1, 0)
        var pos: [SCNVector3] = [], col: [SIMD4<Float>] = [], uv: [CGPoint] = [], idx: [Int32] = []
        for i in 0...n {
            let t: Float = Float(i) / Float(n)
            let p: SIMD3<Float> = path.point(at: t), tg: SIMD3<Float> = path.tangent(at: t)
            let side: SIMD3<Float> = simd_normalize(simd_cross(tg, up))
            let nrm: SIMD3<Float> = simd_normalize(simd_cross(side, tg))
            let a: Float = twist * sin(t * 5 + off) + off * 0.5
            let dir: SIMD3<Float> = nrm * cos(a) + side * sin(a)
            let taper: Float = 1 - 0.85 * t * t
            let w: Float = width * sin(Float.pi * min(t, 0.999) * 0.5) * taper
            let u: Float = t * 2.999
            let k = Int(u)
            let c: SIMD3<Float> = simd_mix(stops[k], stops[min(3, k + 1)], SIMD3<Float>(repeating: u - Float(k)))
            let shift: SIMD3<Float> = side * (off * 0.04)
            for j in 0...m {
                let f: Float = (Float(j) / Float(m) - 0.5) * w
                let q: SIMD3<Float> = p + dir * f + shift
                pos.append(SCNVector3(q)); col.append(SIMD4(c, 1)); uv.append(CGPoint(x: CGFloat(t), y: CGFloat(j) / CGFloat(m)))
            }
        }
        for i in 0..<Int32(n) { for j in 0..<Int32(m) { let a = i * Int32(m + 1) + j, b = a + Int32(m + 1); idx += [a, b, a + 1, b, b + 1, a + 1] } }
        let colors = SCNGeometrySource(data: col.withUnsafeBufferPointer { Data(buffer: $0) }, semantic: .color, vectorCount: col.count,
                                       usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), colors, SCNGeometrySource(textureCoordinates: uv)],
                            elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.white
        mat.isDoubleSided = true
        mat.blendMode = .alpha
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = false
        mat.shaderModifiers = [.fragment: """
        #pragma arguments
        float op;
        float upto;
        #pragma body
        float2 uv = _surface.diffuseTexcoord;
        if (uv.x > upto) { discard_fragment(); }
        float tm = scn_frame.time;
        float e = sin(uv.y * 3.14159);
        float strand = 0.5 + 0.5 * pow(abs(sin(uv.y * 40.0 + tm * 0.6)), 0.6);
        float fade = smoothstep(0.0, 0.25, uv.x);
        float shimmer = 0.85 + 0.15 * sin(uv.x * 30.0 - tm * 3.0);
        float al = op * pow(max(e, 0.0), 0.9) * strand * fade * shimmer;
        float g = uv.x * 2.999;
        float3 c0 = float3(0.0, 0.761, 1.0), c1 = float3(0.482, 0.380, 1.0), c2 = float3(1.0, 0.310, 0.639), c3 = float3(1.0, 0.710, 0.278);
        float3 col = g < 1.0 ? mix(c0, c1, g) : (g < 2.0 ? mix(c1, c2, g - 1.0) : mix(c2, c3, g - 2.0));
        col = pow(col, float3(2.2));
        _output.color = float4(col * al, al);
        """]
        mat.setValue(NSNumber(value: op), forKey: "op")
        mat.setValue(NSNumber(value: 1.0), forKey: "upto")
        g.firstMaterial = mat
        let node = SCNNode(geometry: g)
        node.renderingOrder = 5
        return node
    }

    // MARK: state

    func setMemories(_ mems: [Memory]) {
        lock.lock(); defer { lock.unlock() }
        pearlRoot.childNodes.forEach { $0.removeFromParentNode() }
        pearls = []
        let ts: [Float] = [0.62, 0.22, 0.42, 0.08, 0.32]
        for (i, m) in mems.prefix(5).enumerated() {
            let c = kindColor[m.kind] ?? kindColor[.note]!, s: CGFloat = i == 0 ? 0.1 : 0.08
            let node = SCNNode(geometry: SCNSphere(radius: s))
            node.geometry!.firstMaterial = Self.pearl(c)
            node.renderingOrder = 6
            let halo = SCNNode(), torus = SCNNode(geometry: SCNTorus(ringRadius: s * 1.66, pipeRadius: 0.005))
            torus.geometry!.firstMaterial = Self.flat(c.withAlphaComponent(0.6)); torus.eulerAngles.x = .pi / 2
            halo.addChildNode(torus); halo.constraints = [SCNBillboardConstraint()]
            node.addChildNode(halo)
            pearlRoot.addChildNode(node)
            pearls.append((node, ts[i]))
        }
    }

    func setMode(_ m: HeroMode, focus: Memory?) {
        lock.lock(); defer { lock.unlock() }
        mode = m
        big?.removeFromParentNode(); big = nil
        if m == .answer, let f = focus {
            let c = kindColor[f.kind] ?? kindColor[.note]!
            let b = SCNNode(geometry: SCNSphere(radius: 0.42)); b.geometry!.firstMaterial = Self.pearl(c)
            b.position = SCNVector3(1.1, -0.1, 0.6)
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.62, pipeRadius: 0.006)); ring.geometry!.firstMaterial = Self.flat(c.withAlphaComponent(0.6))
            ring.eulerAngles = SCNVector3(1.2 - .pi / 2, 0.2, 0)
            b.addChildNode(ring)
            b.scale = SCNVector3(0.01, 0.01, 0.01)
            scene.rootNode.addChildNode(b)
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.6
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            b.scale = SCNVector3(1, 1, 1)
            SCNTransaction.commit()
            big = b
        }
    }

    func resize(_ size: CGSize) { if size.height > 0 { aspect = Float(size.width / size.height) } }

    // MARK: animation

    private var camPos = SIMD3<Float>(-0.7, 0.15, 14), camTgt = SIMD3<Float>(-0.7, -0.2, 0)
    private var bPos = SIMD3<Float>(0.12, 0.18, 0), bScale: Float = 0.7, drawT: Float = 1

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        if start == nil { start = time }
        let t = Float(time - start!), ans = mode == .answer, listen = mode == .listen
        // camera framing per mode, eased
        let tgt = SIMD3<Float>(ans ? -0.5 : -0.7, -0.2, 0)
        let k: Float = 2 * tan(Float(15) * Float.pi / 180)
        let fitH: Float = (ans ? 3.1 : 2.9) / k
        let fitW: Float = (ans ? 5.6 : 4.5) / (k * aspect)
        let dist: Float = max(fitH, fitW)
        let ease: Float = 0.08
        camTgt += (tgt - camTgt) * ease
        let want = SIMD3<Float>(tgt.x, tgt.y + 0.35, tgt.z + dist)
        camPos += (want - camPos) * ease
        camera.simdPosition = camPos; camera.simdLook(at: camTgt)
        // flap + float
        let flap: Float = sin(t * (listen ? 9 : 4.2)) * (listen ? 0.5 : 0.32)
        wingR.eulerAngles.y = -0.42 - flap
        wingL.eulerAngles.y = 0.42 + flap
        let target = SIMD3<Float>(ans ? -0.6 : 0.12, ans ? 0.25 : 0.18, 0), sc: Float = ans ? 0.6 : 0.7
        bPos += (target - bPos) * ease; bScale += (sc - bScale) * ease
        let bob: Float = sin(t * 1.3) * 0.06
        butterfly.simdPosition = bPos + SIMD3<Float>(0, bob, 0)
        butterfly.simdScale = SIMD3(repeating: bScale)
        let cycle: Float = (t * 0.25).truncatingRemainder(dividingBy: 1)
        drawT = listen ? 0.55 + 0.45 * cycle : 1
        for r in ribbons { r.geometry?.firstMaterial?.setValue(NSNumber(value: drawT), forKey: "upto") }
        for (i, p) in pearls.enumerated() {
            let lift: Float = sin(t * 1.6 + Float(i)) * 0.03
            p.node.simdPosition = path.point(at: p.t) + SIMD3<Float>(0, lift, 0)
            p.node.isHidden = listen && i == 0
        }
        if let b = big { b.position.y = -0.1 + sin(t * 1.2) * 0.05; b.eulerAngles.y = t * 0.3 }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        frameCount += 1
        guard frameCount % 3 == 0, let onTags else { return }
        lock.lock(); defer { lock.unlock() }
        let pts = pearls.prefix(2).map { p -> CGPoint in
            let v = renderer.projectPoint(p.node.presentation.position)
            return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
        }
        DispatchQueue.main.async { onTags(pts) }
    }

    // MARK: helpers

    private static func pearl(_ c: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = c
        m.roughness.contents = 0.1
        m.metalness.contents = 0.15
        m.clearCoat.contents = 1.0
        m.clearCoatRoughness.contents = 0.05
        return m
    }
    private static func flat(_ contents: Any) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = contents
        m.blendMode = .alpha
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }
    private static func segment(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ r: CGFloat, _ mat: SCNMaterial) -> SCNNode {
        let len = simd_length(b - a)
        let n = SCNNode(geometry: SCNCylinder(radius: r, height: CGFloat(len)))
        n.geometry!.firstMaterial = mat
        n.simdPosition = (a + b) / 2
        n.simdOrientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(b - a))
        return n
    }
    private static func sample(_ p: UIBezierPath) -> [CGPoint] {
        var out: [CGPoint] = [], cur = CGPoint.zero
        p.cgPath.applyWithBlock { el in
            let e = el.pointee, pts = e.points
            switch e.type {
            case .moveToPoint: cur = pts[0]; out.append(cur)
            case .addLineToPoint: cur = pts[0]; out.append(cur)
            case .addCurveToPoint:
                let (c1, c2, to) = (pts[0], pts[1], pts[2])
                for i in 1...24 {
                    let t: CGFloat = CGFloat(i) / 24, u: CGFloat = 1 - t
                    let w0: CGFloat = u * u * u, w1: CGFloat = 3 * u * u * t, w2: CGFloat = 3 * u * t * t, w3: CGFloat = t * t * t
                    let x: CGFloat = w0 * cur.x + w1 * c1.x + w2 * c2.x + w3 * to.x
                    let y: CGFloat = w0 * cur.y + w1 * c1.y + w2 * c2.y + w3 * to.y
                    out.append(CGPoint(x: x, y: y))
                }
                cur = to
            default: break
            }
        }
        if let f = out.first, let l = out.last, hypot(f.x - l.x, f.y - l.y) < 0.001 { out.removeLast() }
        return out
    }
    private static func blob(rgb: (CGFloat, CGFloat, CGFloat), alpha op: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            let c = { (a: CGFloat) in UIColor(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: a).cgColor }
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [c(op), c(op * 0.45), c(0)] as CFArray, locations: [0, 0.5, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 128, y: 128), startRadius: 0, endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
        }
    }
    /// A soft studio: white ceiling, lilac floor, two bright softboxes for highlights on the pearls and wings.
    private static func environmentImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256)).image { ctx in
            let g = ctx.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.white.cgColor, UIColor(hex: 0xF4F0FA).cgColor, UIColor(hex: 0xC9BCEB).cgColor] as CFArray, locations: [0, 0.5, 1])!
            g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
            UIColor.white.setFill()
            g.fill(CGRect(x: 60, y: 40, width: 90, height: 50))
            g.fill(CGRect(x: 330, y: 60, width: 120, height: 36))
        }
    }
}

/// Catmull-Rom curve through points, sampled by arc length like three.js getPointAt.
struct Curve {
    private var samples: [SIMD3<Float>] = [], lengths: [Float] = []
    init(_ p: [SIMD3<Float>]) {
        let n = p.count
        for seg in 0..<(n - 1) {
            let p0 = p[max(seg - 1, 0)], p1 = p[seg], p2 = p[seg + 1], p3 = p[min(seg + 2, n - 1)]
            for i in 0..<40 {
                let t: Float = Float(i) / 40
                let t2: Float = t * t, t3: Float = t2 * t
                let a: SIMD3<Float> = 2 * p1
                let b: SIMD3<Float> = p2 - p0
                var c: SIMD3<Float> = 2 * p0 - 5 * p1
                c += 4 * p2 - p3
                var d: SIMD3<Float> = 3 * p1 - p0
                d += p3 - 3 * p2
                var q: SIMD3<Float> = a + b * t
                q += c * t2 + d * t3
                samples.append(0.5 * q)
            }
        }
        samples.append(p[n - 1])
        var acc: Float = 0; lengths = [0]
        for i in 1..<samples.count { acc += simd_distance(samples[i], samples[i - 1]); lengths.append(acc) }
    }
    func point(at u: Float) -> SIMD3<Float> {
        let target = max(0, min(1, u)) * lengths.last!
        var lo = 0, hi = lengths.count - 1
        while lo < hi - 1 { let mid = (lo + hi) / 2; if lengths[mid] < target { lo = mid } else { hi = mid } }
        let span = lengths[hi] - lengths[lo], f = span > 0 ? (target - lengths[lo]) / span : 0
        return simd_mix(samples[lo], samples[hi], SIMD3(repeating: f))
    }
    func tangent(at u: Float) -> SIMD3<Float> {
        let a = point(at: max(0, u - 0.002)), b = point(at: min(1, u + 0.002))
        return simd_normalize(b - a)
    }
}

extension UIColor {
    convenience init(hex: Int, a: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
    }
    var rgb: (Float, Float, Float) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}

extension SIMD3 where Scalar == Float {
    init(_ t: (Float, Float, Float)) { self.init(t.0, t.1, t.2) }
}
