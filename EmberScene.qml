// EmberScene.qml — the living ember. Pure QML Canvas, ported 1:1 from the
// approved HTML/canvas design. Renders whatever `presence` state it is given
// and eases smoothly between states, so it always feels alive.
import QtQuick

Item {
    id: scene

    // The state the ember should express. Set by Ember.qml from the agents.
    property string presence: "idle"

    // Per-state targets. States differ by MOTION and BRIGHTNESS, never by
    // going cold — Ember is always warm.
    readonly property var states: ({
        "idle":      { energy: 0.28, bright: 0.72, turb: 0.35, breath: 0.55, breathAmp: 0.055, ripple: 0.0,  flick: 0.05 },
        "listening": { energy: 0.60, bright: 1.00, turb: 0.22, breath: 0.80, breathAmp: 0.040, ripple: 0.5,  flick: 0.03 },
        "thinking":  { energy: 0.92, bright: 0.86, turb: 1.00, breath: 1.50, breathAmp: 0.028, ripple: 0.0,  flick: 0.22 },
        "speaking":  { energy: 0.80, bright: 1.00, turb: 0.50, breath: 2.40, breathAmp: 0.050, ripple: 1.6,  flick: 0.06 },
        "alert":     { energy: 0.70, bright: 1.15, turb: 0.40, breath: 1.10, breathAmp: 0.070, ripple: 1.1,  flick: 0.10 }
    })

    // Eased live parameters (morph toward the current state's targets).
    property var p: ({ energy: 0.28, bright: 0.72, turb: 0.35, breath: 0.55, breathAmp: 0.055, ripple: 0.0, flick: 0.05 })
    property var parts: []
    property var ripples: []
    property real rAcc: 0
    property int particleCount: 46

    function lerp(a, b, k) { return a + (b - a) * k }

    function makeParticle(init) {
        var rad = init ? Math.random() : (0.15 + Math.random() * 0.2)
        return {
            a: Math.random() * Math.PI * 2,
            r0: rad,
            spd: (0.2 + Math.random() * 0.8) * (Math.random() < 0.5 ? -1 : 1),
            sz: 0.6 + Math.random() * 2.1,
            life: Math.random(),
            lifeR: 0.15 + Math.random() * 0.5,
            ph: Math.random() * 6.28
        }
    }
    function seed() {
        var arr = []
        for (var i = 0; i < particleCount; i++) arr.push(makeParticle(true))
        parts = arr
    }
    // cheap organic motion from layered sines
    function noise(x, y, t) {
        return Math.sin(x * 1.7 + t * 0.6) * Math.cos(y * 1.3 - t * 0.4) * 0.5
             + Math.sin((x + y) * 0.9 + t * 0.9) * 0.3
             + Math.sin(x * 3.1 - t * 0.5) * 0.2
    }

    Component.onCompleted: seed()

    Canvas {
        id: cv
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = cv.getContext("2d")
            var W = cv.width, H = cv.height
            var t = anim.t, dt = Math.min(0.05, anim.dt)

            // ease params toward the current state
            var tgt = scene.states[scene.presence] || scene.states["idle"]
            var P = scene.p
            var k = 1 - Math.pow(0.0015, dt)
            for (var key in tgt) P[key] = scene.lerp(P[key], tgt[key], k)

            var cx = W / 2, cy = H / 2
            var R = Math.max(40, Math.min(W, H) * 0.16)

            // breathing + flicker
            var breath = Math.sin(t * P.breath * 2 * Math.PI * 0.16) * P.breathAmp
            var flick = (scene.noise(3, 7, t * 2.2) * 0.5 + 0.5) * P.flick
            var scale = 1 + breath
            var bright = P.bright * (1 + (flick - P.flick * 0.5) * 0.6)
            var Rs = R * scale

            // gentle idle drift + thinking churn (attention offset)
            var ax = 0, ay = 0
            if (scene.presence === "thinking") {
                ax = Math.sin(t * 1.7) * R * 0.12; ay = Math.cos(t * 2.3) * R * 0.12
            } else {
                ax = Math.sin(t * 0.4) * R * 0.05; ay = Math.cos(t * 0.33) * R * 0.05
            }
            var ex = cx + ax * 0.6, ey = cy + ay * 0.6

            ctx.clearRect(0, 0, W, H)
            ctx.globalCompositeOperation = "lighter"

            // outer bloom
            var g0 = ctx.createRadialGradient(ex, ey, 0, ex, ey, Rs * 2.6)
            g0.addColorStop(0, "rgba(244,182,120," + (0.16 * bright) + ")")
            g0.addColorStop(0.4, "rgba(232,135,90," + (0.09 * bright) + ")")
            g0.addColorStop(1, "rgba(176,74,47,0)")
            ctx.fillStyle = g0
            ctx.beginPath(); ctx.arc(ex, ey, Rs * 2.6, 0, 6.2832); ctx.fill()

            // volumetric body — drifting metaball gradients
            var blobs = 5
            for (var b = 0; b < blobs; b++) {
                var ph = b / blobs * 6.2832
                var wob = scene.noise(b * 2.1, b * 1.3, t) * R * 0.16
                var bx = ex + Math.cos(t * 0.5 + ph) * (R * 0.12) + wob
                var by = ey + Math.sin(t * 0.6 + ph) * (R * 0.12) + wob * 0.6
                var br = Rs * (0.55 + 0.12 * Math.sin(t * 0.7 + ph))
                var gg = ctx.createRadialGradient(bx, by, 0, bx, by, br)
                gg.addColorStop(0, "rgba(246,233,220," + (0.13 * bright) + ")")
                gg.addColorStop(0.35, "rgba(244,182,120," + (0.12 * bright) + ")")
                gg.addColorStop(0.75, "rgba(232,135,90," + (0.07 * bright) + ")")
                gg.addColorStop(1, "rgba(176,74,47,0)")
                ctx.fillStyle = gg
                ctx.beginPath(); ctx.arc(bx, by, br, 0, 6.2832); ctx.fill()
            }

            // bright kernel
            var kr = Rs * (0.3 + 0.05 * Math.sin(t * P.breath * 3))
            var gk = ctx.createRadialGradient(ex, ey, 0, ex, ey, kr)
            gk.addColorStop(0, "rgba(255,247,235," + (0.9 * bright) + ")")
            gk.addColorStop(0.3, "rgba(246,222,196," + (0.5 * bright) + ")")
            gk.addColorStop(1, "rgba(244,182,120,0)")
            ctx.fillStyle = gk
            ctx.beginPath(); ctx.arc(ex, ey, kr, 0, 6.2832); ctx.fill()

            // currents / particles
            var arr = scene.parts
            for (var i = 0; i < arr.length; i++) {
                var q = arr[i]
                q.life += dt * q.lifeR * (0.4 + P.energy)
                if (q.life > 1) { arr[i] = scene.makeParticle(false); continue }
                q.a += q.spd * dt * (0.3 + P.turb * 1.4)
                var nz = scene.noise(Math.cos(q.a) * 2 + q.ph, Math.sin(q.a) * 2, t * (0.6 + P.turb)) * P.turb
                var baseR = q.r0 * (0.9 + 0.5 * Math.sin(q.life * Math.PI))
                var rr = Rs * (baseR + nz * 0.18)
                var ang = q.a + nz * 0.5
                var xx = ex + Math.cos(ang) * rr
                var yy = ey + Math.sin(ang) * rr
                var fade = Math.sin(q.life * Math.PI)
                var al = fade * (0.5 + P.energy * 0.5) * bright
                var size = q.sz * (0.7 + fade * 0.8)
                var cg = ctx.createRadialGradient(xx, yy, 0, xx, yy, size * 3)
                cg.addColorStop(0, "rgba(255,236,210," + (al * 0.9) + ")")
                cg.addColorStop(0.5, "rgba(244,164,104," + (al * 0.5) + ")")
                cg.addColorStop(1, "rgba(232,135,90,0)")
                ctx.fillStyle = cg
                ctx.beginPath(); ctx.arc(xx, yy, size * 3, 0, 6.2832); ctx.fill()
            }

            // ripples (speaking / alert / listening)
            scene.rAcc += dt * P.ripple
            if (scene.rAcc > 0.5 && P.ripple > 0.15) {
                scene.rAcc = 0
                scene.ripples.push({ r: R * 0.5, a: 0.5 })
            }
            for (var ri = scene.ripples.length - 1; ri >= 0; ri--) {
                var rp = scene.ripples[ri]
                rp.r += dt * R * 1.7
                rp.a -= dt * 0.55
                if (rp.a <= 0) { scene.ripples.splice(ri, 1); continue }
                ctx.beginPath()
                ctx.lineWidth = 2
                ctx.strokeStyle = "rgba(244,182,120," + (rp.a * 0.5 * bright) + ")"
                ctx.arc(ex, ey, rp.r, 0, 6.2832); ctx.stroke()
            }

            ctx.globalCompositeOperation = "source-over"
        }
    }

    // vsynced clock; drives repaint
    FrameAnimation {
        id: anim
        running: scene.visible
        property real t: 0
        property real dt: 0.016
        onTriggered: { t = anim.elapsedTime; dt = anim.frameTime; cv.requestPaint() }
    }
}
