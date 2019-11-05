#!/bin/bash
#

set -e
set -u
shopt -s nullglob

# Utility functions

set_kernel_config() {
    # flag as $1, value to set as $2, config must exist at "./.config"
    local TGT="CONFIG_${1#CONFIG_}"
    local REP="${2//\//\\/}"
    if grep -q "^${TGT}[^_]" .config; then
        sed -i "s/^\(${TGT}=.*\|# ${TGT} is not set\)/${TGT}=${REP}/" .config
    else
        echo "${TGT}=${2}" >> .config
    fi
}

unset_kernel_config() {
    # unsets flag with the value of $1, config must exist at "./.config"
    local TGT="CONFIG_${1#CONFIG_}"
    sed -i "s/^${TGT}=.*/# ${TGT} is not set/" .config
}

# Custom config settings follow

# Ceph / RBD
set_kernel_config CONFIG_CEPH_FSCACHE y
set_kernel_config CONFIG_CEPH_FS m
set_kernel_config CONFIG_CEPH_FS_POSIX_ACL y
set_kernel_config CONFIG_CEPH_LIB m
set_kernel_config CONFIG_CEPH_LIB_USE_DNS_RESOLVER y
set_kernel_config CONFIG_CEPH_LIB_PRETTYDEBUG y
set_kernel_config CONFIG_FSCACHE m
set_kernel_config CONFIG_FSCACHE_STATS y
set_kernel_config CONFIG_LIBCRC32C m
set_kernel_config CONFIG_BLK_DEV_RBD y

# CPU bandwidth provisioning for FAIR_GROUP_SCHED
set_kernel_config CONFIG_CFS_BANDWIDTH y

# Stream parsing
set_kernel_config CONFIG_STREAM_PARSER y
set_kernel_config CONFIG_BPF_STREAM_PARSER y
set_kernel_config CONFIG_BPF_LIRC_MODE2 y

# XDP sockets
set_kernel_config CONFIG_XDP_SOCKETS y

# NF Tables / NAT settings
set_kernel_config CONFIG_NF_TABLES_INET y
set_kernel_config CONFIG_NF_TABLES_IPV4 y
set_kernel_config CONFIG_NF_TABLES_IPV6 y
set_kernel_config CONFIG_NF_TABLES_NETDEV y
set_kernel_config CONFIG_NF_TABLES_ARP y
set_kernel_config CONFIG_NF_TABLES_BRIDGE y
set_kernel_config CONFIG_NF_NAT_MASQUERADE_IPV4 y
set_kernel_config CONFIG_NF_NAT_MASQUERADE_IPV6 y
set_kernel_config CONFIG_NF_NAT_REDIRECT y

# Enable ARM kernel workarounds
set_kernel_config CONFIG_ARM64_ERRATUM_834220 y

# Default power mode
unset_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE
set_kernel_config CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND y

# HDMI CRC
set_kernel_config CONFIG_MEDIA_CEC_RC n
set_kernel_config SMS_SIANO_RC n

# Enable kernel audit
set_kernel_config CONFIG_AUDIT y
set_kernel_config CONFIG_HAVE_ARCH_AUDITSYSCALL y
set_kernel_config CONFIG_AUDITSYSCALL y
set_kernel_config CONFIG_NETFILTER_XT_TARGET_AUDIT m

# Enable YAMA/Ptrace
set_kernel_config CONFIG_SECURITY_YAMA y

# Crypto
set_kernel_config CONFIG_CRYPTO_ENGINE m
set_kernel_config CONFIG_CRYPTO_SHA256_ARM64 m
set_kernel_config CONFIG_CRYPTO_SHA512_ARM64 m
set_kernel_config CONFIG_CRYPTO_SHA1_ARM64_CE m
set_kernel_config CONFIG_CRYPTO_SHA2_ARM64_CE m
set_kernel_config CONFIG_CRYPTO_GHASH_ARM64_CE m
set_kernel_config CONFIG_CRYPTO_CRCT10DIF_ARM64_CE m
set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE m
set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE_CCM m
set_kernel_config CONFIG_CRYPTO_AES_ARM64_CE_BLK m
set_kernel_config CONFIG_CRYPTO_CHACHA20_NEON m

# Security
set_kernel_config CONFIG_PERSISTENT_KEYRINGS y
set_kernel_config ONFIG_BIG_KEYS y
set_kernel_config CONFIG_TRUSTED_KEYS y
set_kernel_config CONFIG_ENCRYPTED_KEYS y
set_kernel_config CONFIG_SECURITY y