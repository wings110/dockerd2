#!/system/bin/sh
DIR=${0%/*}
source $DIR/../settings.ini

stop_service() {
  if [ -f "${dockerd_run_dir}/dockerd.pid" ]; then
    "${dockerd_service}" stop >> "/dev/null" 2>&1
  fi
}
start_service() {
  if [ ! -f "${module_dir}/disable" ]; then
    "${dockerd_service}" start >> "/dev/null" 2>&1
  fi
}
start_inotifyd() {
  PIDs=($(busybox pidof inotifyd))
  for PID in "${PIDs[@]}"; do
    if grep -q "${dockerd_inotify}" "/proc/$PID/cmdline"; then
      kill -9 "$PID"
    fi
  done
  echo "${current_time} [Info]: Starting dockerd inotify service" > "${dockerd_service_log}"
  inotifyd "${dockerd_inotify}" "${module_dir}" >> "/dev/null" 2>&1 &
}
mkdir -p ${dockerd_run_dir}
rm -f ${dockerd_runs_log}
module_version=$(busybox awk -F'=' '!/^ *#/ && /version=/ { print $2 }' "$module_prop" 2>/dev/null)
log Info "Magisk Dockerd version : ${module_version}."
start_service
start_inotifyd
