#!/system/bin/sh
# The network namespaces of the SDV agents (service discovery, data tunnel) on one device:
# in a car each holds a VLAN to the other machines, here loopback only.
set -e
for ns in sd_mesh_ns sdv_dt_ns; do
  ip netns add "$ns"
  ip -n "$ns" link set lo up
done
log -t boot-timing -p i "sdv-sd-mesh-local has started successfully"
