# Netconnect_ha

CA UIM Net_connect High availability

This probe bring high availability for net_connect probe. It can be useful if you split your pings profiles between multiple net_connect (On the active & passive hub for example). So, if the active hub go down you are not going to loose any pings monitoring.

This probe work like the HA probe. It was created with the objective of managing a single node. But this time you have to install the probe on both hub (bi-directionnal HA).

You have to be vigilant if you mix this probe with any kind of net_connect provisionning mechanism (can generate collision between them). I'm working on a way to manage this (AKA daemon probe with callback).

# Configuration 

```xml
<setup>
    domain = DOMAIN
    audit = 1
    nim_login = administrator
    nim_password = password
    output_directory = output
    output_cache_time = 432000
</setup>
``` 

Keys nim_login and nim_password are not required in probe mode. Ouput_cache_time field are seconds.

---

```xml
<configuration>
    daemon_mode = yes
    daemon_timeout = 27
    nim_addr = /DOMAIN/HUB-NAME/ROBOTNAME
    netconnect_online = no
    sync_path = storage
</configuration>
```

| Key | Value (type) | Description |
| --- | --- | --- |
| daemon_mode | yes or no | Active the probe as daemon, if not the probe is configured as timed | 
| daemon_timeout | Integer | Timeout time in second * 5, example 10 is equal to 50 seconds | 
| nim_addr | String | The remote hub nim addr where the net_connect is | 
| netconnect_online | yes or no | If set to yes, the HA is activated when the remote net_connect is deactivated | 
| sync_path | String | The directory name where sync_state and net_connect .cfg are stored | 

# Documentation

Find the documentation [Here](https://github.com/fraxken/netconnect_ha/wiki)

# Requirement 

This probe require [perluim 4.2](https://github.com/fraxken/perluim) or higher.

# Roadmap next releases

- Implementation restore_old callback (restore before ha configuration).
- Update PerlUIM to v4.3
- Implement cfgManager prototype in the core to simplify the whole code.
