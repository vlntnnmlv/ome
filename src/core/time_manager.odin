package omecore

import "core:time"

TimeManager :: struct {
	period_start:   time.Time,
	period_elapsed: time.Duration,
	frame_start:    time.Time,
	fps:            f64,
	frame_count:    int,
	dt:             f32,
	time:           f32,
}

time_manager_start :: proc(time_manager: ^TimeManager) {
	time_manager.period_start = time.now()
}

time_manager_capture_frame_start :: proc(time_manager: ^TimeManager) {
	time_manager.frame_start = time.now()
}

time_manager_update :: proc(time_manager: ^TimeManager) {
	time_manager.frame_count += 1
	time_manager.period_elapsed = time.since(time_manager.period_start)
	elapsed_duration := time.duration_seconds(time_manager.period_elapsed)
	if elapsed_duration >= 1.0 {
		time_manager.fps = f64(time_manager.frame_count) / elapsed_duration

		time_manager.frame_count = 0
		time_manager.period_start = time.now()
	}

	time_manager.dt = cast(f32)time.duration_seconds(time.since(time_manager.frame_start))
	time_manager.time += time_manager.dt
}
