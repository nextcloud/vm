# What is this folder about?
This folder is only meant for storing GeoIP Legacy Databases which are used by the [geoip script](https://github.com/nextcloud/vm/blob/master/network/geoblock.sh).

All .dat files in this folder are from https://www.miyuru.lk/geoiplegacy and converted by Miyuru Sankalpa.

## How to add updated Database files in here?
1. Check if the files were updated by Miyuru Sankalpa by visiting [twitter](https://twitter.com/miyurulk) or verifying the **Last Updated** tag on his [website](https://www.miyuru.lk/geoiplegacy)
2. If the files were updated, download the newest [Maxmind Country IPv4](https://dl.miyuru.lk/geoip/maxmind/country/maxmind4.dat.gz) and [Maxmind Country IPv6](https://dl.miyuru.lk/geoip/maxmind/country/maxmind6.dat.gz) files
3. Extract them
4. Create a PR with those updated database files, add them to this folder and follow this naming scheme:

### Naming scheme:
**for IPv4:**<br>
`yyyy-mm-Maxmind-Country-IPv4.dat`<br>
**for IPv6:**<br>
`yyyy-mm-Maxmind-Country-IPv6.dat`<br>
_(Year and month should be chosen based on when the files were updated by Sankalpa)_<br><br>
**One example is:**<br>
`2020-09-Maxmind-Country-IPv4.dat`<br>
and<br>
`2020-09-Maxmind-Country-IPv6.dat`<br>
_(If the files were updated on September 2020 by Sankalpa)_
