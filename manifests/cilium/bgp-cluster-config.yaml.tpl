# https://docs.cilium.io/en/latest/network/bgp-control-plane/
---
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPClusterConfig
metadata:
  name: default
  namespace: cilium-system
spec:
  nodeSelector:
    matchLabels:
      cilium/bgp-peering-policy: default
  virtualRouters:
    - localASN: ${cilium_asn}
      exportPodCIDR: true
      neighbors:
        - peerAddress: ${router_ip}/32
          peerASN: ${router_asn}
          ebgpMultihop:
            enabled: true
            ttl: 10
          timers:
            connectRetry: 120s
            holdTime: 90s
            keepAlive: 30s
            gracefulRestart:
              enabled: true
              restartTime: 120s
      serviceSelector:
        matchExpressions:
          - key: somekey
            operator: NotIn
            values:
              - never-used-value
