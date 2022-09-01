# Echelon State Syncer

The script can be used to interactively or non-interactively setup and start state syncing on an Echelon blockchain node. State sync snapshots are fetched from [public Echelon nodes hosted by ech.world](https://ech.world/nodes). State sync shortens the time needed for syncing a new node or re-syncing an existing node which has been offline. More info about state syncs in [this article](https://blog.cosmos.network/cosmos-sdk-state-sync-guide-99e4cf43be2f)

## Usage

**Before running the script, please backup per you own needs:** validator private key, .echelond/config/config.toml, .echelon/config/addrbook.json

Also, if you want to store your current indexed etc. data in node's data folder, you should copy/move it somewhere because the script will reset the data folder

You can download the script and run it on your server. In this case, remember to set execute permissions by running:
```
chmod +x state-sync.sh
```

Alternatively you can run the following command on your server which will download the script from Github and run it

```
bash <(wget -qO- https://raw.githubusercontent.com/ech-world/ech-state-syncer/main/state-sync.sh)
```

## What does it do?

The script
* prompts for node's _.echelond_ folder path
* gets state sync parameters from an RPC server (current block height, trusted height and hash)
* prompts for confirmation to proceed
* sets state sync parameters and adds [ech.world](https://ech.world) public peers to node's config.toml
* stops the node on your server
* prompts for confirmation to proceed
* resets the node: data folder will be emptied, addressbook removed and validator file partially reseted
* starts the node: node will start syncing to state sync snapshot

Please notice that using the script is totally on your own responsibility. I’ve done my best to make it safe and reliable but it’s an [MIT licensed](/LICENSE) release, I am not liable if something unexpected happens that you don’t like

## Non-interactive mode

If you're planning on running a scheduled/automated state sync without human interaction, you can use the _-y_ switch on command line which will run all the steps without confirming anything from the user (system might naturally prompt for sudo passwords if you run it manually with the _-y_ switch)

Syntax:
```
state-sync.sh -y [.echelond full path]
```

For example:
```
./state-sync.sh -y /home/echelon/.echelond
```

If no path is given, /home/echelon/.echelond is used as a default

## Alternative snapshot states

Alternatively a snapshot of the whole data folder can be imported. Either of these methods does the trick:
1. use the [Echelon Snapshot Importer](https://github.com/ech-world/ech-snapshot-importer/) script
2. download the snapshot from [ech.world](https://ech.world/snapshots/#import-snapshot-manually) and import it to your server manually
