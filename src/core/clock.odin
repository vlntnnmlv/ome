package omecore

import "core:time"

Clock :: struct {
	period_start:   time.Time,
	period_elapsed: time.Duration,
	frame_start:    time.Time,
	fps:            f64,
	frame_count:    int,
	dt:             f32,
	time:           f32,
}

clock_start :: proc(clock: ^Clock) {
	clock.period_start = time.now()
}

clock_capture_frame_start :: proc(clock: ^Clock) {
	clock.frame_start = time.now()
}

clock_update :: proc(clock: ^Clock) {
	clock.frame_count += 1
	clock.period_elapsed = time.since(clock.period_start)
	elapsed_duration := time.duration_seconds(clock.period_elapsed)
	if elapsed_duration >= 1.0 {
		clock.fps = f64(clock.frame_count) / elapsed_duration

		clock.frame_count = 0
		clock.period_start = time.now()
	}

	clock.dt = cast(f32)time.duration_seconds(time.since(clock.frame_start))
	clock.time += clock.dt
}
