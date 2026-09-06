// EmberScene.qml — the living ember. Pure QML Canvas.
// It is not a loading widget: thinking EVOLVES (wandering churn + insight
// surges), and listening/speaking react to a live audio `level` (0..1) so it
// feels like it genuinely hears you and talks back.
import QtQuick

Item {
    id: scene

    property string presence: "idle"   // idle | listening | thinking | speaking | alert
    property real   inLevel: 0          // live audio level 0..1 (from mic / TTS)

    // Per-state targets. States differ by MOTION + BRIGHTNESS, never by going
    // cold — Ember is always warm.
    readonly property var states: ({
        "idle":      { energy: 0.28, bright: 0.72, turb: 0.35, breath: 0.55, breathAmp: 0.055, ripple: 0.0, flick: 0.05 },
        "listening": { energy: 0.60, bright: 1.00, turb: 0.22, breath: 0.80, breathAmp: 0.040, ripple: 0.5, flick: 0.03 },
        "thinking":  { energy: 0.92, bright: 0.86, turb: 1.00, breath: 1.50, breathAmp: 0.028, ripple: 0.0, flick: 0.22 },
        "speaking":  { energy: 0.80, bright: 1.00, turb: 0.50, breath: 2.40, breathAmp: 0.050, ripple: 1.6, flick: 0.06 },
        "alert":     { energy: 0.70, bright: 1.15, turb: 0.40, breath: 1.10, breathAmp: 0.070, ripple: 1.1, flick: 0.10 }
    })

    property var  p: ({ energy: 0.28, bright: 0.72, turb: 0.35, breath: 0.55, breathAmp: 0.055, ripple: 0.0, flick: 0.05 })
    property var  parts: []
    property var  ripples: []
    property real rAcc: 0
    property real lvl: 0            // smoothed audio level
    property real surge: 0         // "insight" flash during thinking
    property real nextSurge: 3
    property int  particleCount: 46

    function lerp(a, b, k) { return a + (b - a) * k }

    function makeParticle(init) {
        var rad = init ? Math.random() : (0.15 + Math.random() * 0.2)
        return { a: Math.random() * Math.PI * 2, r0: rad,
                 spd: (0.2 + Math.random() * 0.8) * (Math.random() < 0.5 ? -1 : 1),
                 sz: 0.6 + Math.random() * 2.1, life: Math.random(),
                 lifeR: 0.15 + Math.random() * 0.5, ph: Math.random() * 6.28 }
    }
    function seed() {
        var arr = []
        for (var i = 0; i < particleCount; i++) arr.push(makeParticle(true))
        parts = arr
    }
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
        renderTarget: Canvas.Image   // truly transparent (FBO backing is opaque)

        onPaint: {
            var ctx = cv.getContext("2d")
            var W = cv.width, H = cv.height
            var t = anim.t, dt = Math.min(0.05, anim.dt)
            var P = scene.p

            // ease state params
            var tgt = scene.states[scene.presence] || scene.states["idle"]
            var k = 1 - Math.pow(0.0015, dt)
            for (var key in tgt) P[key] = scene.lerp(P[key], tgt[key], k)

            // smooth the audio level — fast attack, gentle release
            var target = scene.inLevel
            var kk = target > scene.lvl ? (1 - Math.pow(0.0002, dt)) : (1 - Math.pow(0.05, dt))
            scene.lvl = scene.lvl + (target - scene.lvl) * kk
            var L = scene.lvl
            var audio = scene.inLevel > 0.003 || L > 0.01

            var cx = W / 2, cy = H / 2
            var R = Math.max(40, Math.min(W, H) * 0.16)

            // thinking never loops: churn waxes and wanes
            var turbLFO = 0.6 + 0.55 * (0.5 + 0.5 * Math.sin(t * 0.29)) + 0.2 * Math.sin(t * 0.13 + 1.1)
            var eTurb = P.turb * turbLFO

            // thinking "insight" surges
            if (scene.presence === "thinking" && t > scene.nextSurge) {
                scene.surge = 1
                scene.nextSurge = t + 2.5 + Math.random() * 3.5
                scene.ripples.push({ r: R * 0.4, a: 0.3, w: 1 })
            }
            scene.surge = Math.max(0, scene.surge - dt * 1.6)

            // breathing + flicker
            var breath = Math.sin(t * P.breath * 2 * Math.PI * 0.16) * P.breathAmp
            var flick = (scene.noise(3, 7, t * 2.2) * 0.5 + 0.5) * P.flick
            var scale = 1 + breath
            var bright = P.bright * (1 + (flick - P.flick * 0.5) * 0.6)
            var Rs = R * scale

            // reactive: the core swells + brightens with your voice
            if (audio && scene.presence === "speaking") { Rs *= (1 + L * 0.30); bright *= (1 + L * 0.62) }
            else if (audio && scene.presence === "listening") { Rs *= (1 + L * 0.17); bright *= (1 + L * 0.48) }
            // insight flash
            bright *= (1 + scene.surge * 0.5)
            Rs *= (1 + scene.surge * 0.10)

            // gentle drift / thinking churn (attention offset)
            var ax, ay
            if (scene.presence === "thinking") { ax = Math.sin(t * 1.7) * R * 0.12; ay = Math.cos(t * 2.3) * R * 0.12 }
            else { ax = Math.sin(t * 0.4) * R * 0.05; ay = Math.cos(t * 0.33) * R * 0.05 }
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

            // volumetric body
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
            var kr = Rs * (0.3 + 0.05 * Math.sin(t * P.breath * 3)) * (1 + (audio ? L * 0.25 : 0))
            var gk = ctx.createRadialGradient(ex, ey, 0, ex, ey, kr)
            gk.addColorStop(0, "rgba(255,247,235," + (0.9 * bright) + ")")
            gk.addColorStop(0.3, "rgba(246,222,196," + (0.5 * bright) + ")")
            gk.addColorStop(1, "rgba(244,182,120,0)")
            ctx.fillStyle = gk
            ctx.beginPath(); ctx.arc(ex, ey, kr, 0, 6.2832); ctx.fill()

            // currents / particles
            var eEnergy = P.energy * (audio ? (0.8 + L * 0.7) : 1)
            var arr = scene.parts
            for (var i = 0; i < arr.length; i++) {
                var q = arr[i]
                q.life += dt * q.lifeR * (0.4 + eEnergy)
                if (q.life > 1) { arr[i] = scene.makeParticle(false); continue }
                q.a += q.spd * dt * (0.3 + eTurb * 1.4)
                var nz = scene.noise(Math.cos(q.a) * 2 + q.ph, Math.sin(q.a) * 2, t * (0.6 + eTurb)) * eTurb
                var baseR = q.r0 * (0.9 + 0.5 * Math.sin(q.life * Math.PI))
                var rr = Rs * (baseR + nz * 0.18)
                var ang = q.a + nz * 0.5
                var xx = ex + Math.cos(ang) * rr
                var yy = ey + Math.sin(ang) * rr
                var fade = Math.sin(q.life * Math.PI)
                var al = fade * (0.5 + eEnergy * 0.5) * bright
                var size = q.sz * (0.7 + fade * 0.8)
                var cg = ctx.createRadialGradient(xx, yy, 0, xx, yy, size * 3)
                cg.addColorStop(0, "rgba(255,236,210," + (al * 0.9) + ")")
                cg.addColorStop(0.5, "rgba(244,164,104," + (al * 0.5) + ")")
                cg.addColorStop(1, "rgba(232,135,90,0)")
                ctx.fillStyle = cg
                ctx.beginPath(); ctx.arc(xx, yy, size * 3, 0, 6.2832); ctx.fill()
            }

            // ripples — the "voice". When audio is driving, cadence + size track
            // the level, so speech makes rings and silence makes none.
            var ripRate = P.ripple
            if (audio && (scene.presence === "speaking" || scene.presence === "listening"))
                ripRate = P.ripple * (0.2 + L * 2.6)
            scene.rAcc += dt * ripRate
            if (scene.rAcc > 0.5 && ripRate > 0.05) {
                scene.rAcc = 0
                var amp = audio ? (0.3 + L * 1.0) : 0.5
                scene.ripples.push({ r: R * 0.5, a: 0.5 * Math.min(1, amp), w: 1 + (audio ? L * 2.4 : 0) })
            }
            for (var ri = scene.ripples.length - 1; ri >= 0; ri--) {
                var rp = scene.ripples[ri]
                rp.r += dt * R * 1.7
                rp.a -= dt * 0.55
                if (rp.a <= 0) { scene.ripples.splice(ri, 1); continue }
                ctx.beginPath()
                ctx.lineWidth = 1.5 * (rp.w || 1)
                ctx.strokeStyle = "rgba(244,182,120," + (rp.a * 0.5 * bright) + ")"
                ctx.arc(ex, ey, rp.r, 0, 6.2832); ctx.stroke()
            }

            ctx.globalCompositeOperation = "source-over"
        }
    }

    FrameAnimation {
        id: anim
        running: scene.visible
        property real t: 0
        property real dt: 0.016
        onTriggered: { t = anim.elapsedTime; dt = anim.frameTime; cv.requestPaint() }
    }
}
