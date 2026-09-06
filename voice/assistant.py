#!/usr/bin/env python3
"""Ember Voice — a hands-free voice assistant that drives the Ember presence.

Pipeline (all local except the brain, which is your logged-in `claude` CLI):
  mic  ->  faster-whisper (STT)  ->  claude -p (brain)  ->  piper (TTS)  ->  speakers
Ember reacts the whole way: listening (swells with your voice), thinking
(evolving churn), speaking (ripples pulse with the reply).

Just run it and talk. It hears you start, waits for you to stop, then answers.
Ctrl-C to quit.
"""
import os, sys, time, math, array, subprocess, threading, wave, tempfile

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE = os.path.join(RUNTIME, "ember"); os.makedirs(STATE, exist_ok=True)
STATEFILE = os.path.join(STATE, "state")
DATA = os.path.expanduser("~/.local/share/ember-voice")
VOICES = os.path.join(DATA, "voices")

def ember(line):
    try:
        with open(STATEFILE, "w") as f: f.write(line + "\n")
    except Exception: pass

RATE = 16000
FRAME = int(RATE * 0.03)          # 30 ms
GATE = 0.015                      # speech threshold

def rms_of(samples):
    if not samples: return 0.0
    s = 0
    for v in samples: s += v * v
    return math.sqrt(s / len(samples)) / 32768.0

def record_utterance(max_s=15.0, tail_silence=1.0):
    """Record from the mic until you stop talking. Streams 'listening <lvl>'."""
    src = subprocess.run(["pactl","get-default-source"], capture_output=True, text=True).stdout.strip()
    p = subprocess.Popen(
        ["parec","-d",src,"--format=s16le",f"--rate={RATE}","--channels=1","--latency-msec=30"],
        stdout=subprocess.PIPE)
    pcm = array.array('h')
    started = False
    t0 = time.time(); last_voice = t0; last_write = 0.0; lvl = 0.0
    ember("listening")
    try:
        while True:
            raw = p.stdout.read(FRAME*2)
            if not raw or len(raw) < FRAME*2: break
            fr = array.array('h'); fr.frombytes(raw)
            r = rms_of(fr)
            x = min(1.0, max(0.0, r - GATE) * 6.0) ** 0.6
            lvl += (x - lvl) * (0.6 if x > lvl else 0.3)
            now = time.time()
            if now - last_write >= 0.066:
                ember(f"listening {lvl:.3f}"); last_write = now
            if r > GATE:
                if not started:
                    started = True
                last_voice = now
                pcm.extend(fr)
            elif started:
                pcm.extend(fr)
                if now - last_voice > tail_silence: break
            if now - t0 > max_s: break
    finally:
        p.terminate()
    return pcm if started else array.array('h')

def to_float32(pcm):
    try:
        import numpy as np
        a = np.frombuffer(pcm.tobytes(), dtype=np.int16).astype("float32") / 32768.0
        return a
    except Exception:
        return [s / 32768.0 for s in pcm]

def speak(wav_path):
    """Play a wav while streaming 'speaking <lvl>' from its envelope."""
    # precompute 50ms RMS envelope
    env = []
    with wave.open(wav_path, "rb") as wf:
        sr = wf.getframerate(); ch = wf.getnchannels(); n = wf.getnframes()
        step = int(sr * 0.05)
        while True:
            frames = wf.readframes(step)
            if not frames: break
            a = array.array('h'); a.frombytes(frames)
            if ch > 1: a = a[::ch]
            env.append(min(1.0, rms_of(a) * 3.5))
    ember("speaking")
    play = subprocess.Popen(["pw-play", wav_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    for i, e in enumerate(env):
        ember(f"speaking {e:.3f}")
        target = t0 + (i + 1) * 0.05
        dt = target - time.time()
        if dt > 0: time.sleep(dt)
    play.wait()

def ask_claude(text):
    prompt = ("You are Ember, a concise spoken voice assistant. Reply in 1-3 short "
              "sentences of plain speech — no markdown, no lists, no emoji. "
              f'The user said: "{text}"')
    try:
        out = subprocess.run(["claude","-p",prompt], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120)
        return out.stdout.strip() or "Sorry, I didn't catch a reply."
    except Exception as e:
        return f"The brain isn't responding right now."

def main():
    # lazy heavy imports
    ember("idle")
    print("Loading speech model…")
    from faster_whisper import WhisperModel
    model = WhisperModel(os.environ.get("EMBER_WHISPER","base.en"), device="cpu", compute_type="int8")

    from piper import PiperVoice
    voice_name = os.environ.get("EMBER_VOICE","en_US-amy-medium")
    onnx = os.path.join(VOICES, voice_name + ".onnx")
    if not os.path.exists(onnx):
        print(f"Missing voice {voice_name} at {onnx}", file=sys.stderr); sys.exit(2)
    tts = PiperVoice.load(onnx)

    print("\n🟠  Ember is listening. Just talk — pause when you're done. Ctrl-C to quit.\n")
    while True:
        input_ready = True
        pcm = record_utterance()
        if len(pcm) < RATE * 0.3:
            ember("idle"); continue
        ember("thinking")
        segs, _ = model.transcribe(to_float32(pcm), language="en", beam_size=1)
        said = " ".join(s.text for s in segs).strip()
        if not said:
            ember("idle"); continue
        print(f"you › {said}")
        reply = ask_claude(said)
        print(f"ember › {reply}\n")
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
            wavp = tf.name
        with wave.open(wavp, "wb") as wf:
            tts.synthesize_wav(reply, wf)
        speak(wavp)
        os.unlink(wavp)
        ember("idle")

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt:
        ember("idle"); print("\nbye 👋")
