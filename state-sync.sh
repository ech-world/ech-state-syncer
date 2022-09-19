#!/bin/bash

if ! [ -x "$(command -v jq)" ]
then
	echo
	echo "Error: 'jq' not found on system. Please install it before running this script (for example on Ubuntu: sudo apt install jq)"
	echo "Exiting..."
	echo
	exit 1
fi

#
# configs
#

# set default sync block range
syncRange=1000
# default is to prompt confirmations from the user
prompts=true
# let's populate the rpc and peer data
rpc1="https://rpc.eu.ech.world:443"
peer1="ab8febad726c213fac69361c8fd47adc3f302e64@38.242.143.4:26656"
rpc2="https://rpc.us.ech.world:443"
peer2="7af104b97f68b21f474bf5caff35ba9d0720138b@154.12.227.53:26656"

#
# CLI arguments
#

# if -y is given as arg1 on CLI, use non-interactive mode
if [ -n "$1" ] && [ "$1" = "-y" ]
then
	prompts=false
fi

# if .echelond path is given as arg2 on CLI, populate it here
if [ -n $2 ]
then
	targetpath=$2
fi

# splash texts
echo
echo "*** Echelon State Syncer ***"
echo "https://github.com/ech-world/ech-state-syncer"
echo "https://ech.world"
echo
echo "This script"
echo "1. gets state sync parameters from RPC servers (current block height, trusted height and hash)"
echo "2. sets state sync parameters to node's config.toml"
echo "3. stops the node"
echo "4. resets the node: data folder will be emptied, addressbook removed and validator file partially reseted"
echo "5. starts the node: node will start syncing to state sync snapshot (snapshot height is within ${syncRange} blocks from current height)"
echo
echo "Script can be started in non-interactive mode (-y) which will run all the steps without confirming anything from the user (system might prompt for sudo passwords)"
echo "Non-interactive mode: state-sync.sh -y [.echelond full path]"
echo "For example: ./state-sync.sh -y /home/echelon/.echelond"
echo "If no path is given, /home/echelon/.echelond is used as a default"
echo
echo "MIT-license: https://github.com/ech-world/ech-state-syncer/blob/main/LICENSE"
echo "It is your responsibility to make necessary backups if you still need the existing data in node's data folder or address book"
echo "Also, always make sure you have backed up your validator key (priv_validator_key.json)"
echo "Back up any important data!"
echo

if [ "${prompts}" = true ]
then
	# we need the user to confirm .echelond folder path here
	echo "Enter .echelond folder's full path, don't use '~' (leave empty to use /home/echelon/.echelond):"
	read targetpath
fi

# check if we have a value for .echelond path at this point
if [ -z "${targetpath}" ]
then
	# populate default value here, if variable is still empty
	targetpath="/home/echelon/.echelond"
fi

# populate config.toml full path
configFile="${targetpath}/config/config.toml"

# check if config.toml exists
if [ -f "${configFile}" ]
then
	echo "${configFile} found, ok!"
else
	echo "${configFile} not found! Exiting..."
	exit 1
fi

# get state sync parameters
echo "Getting state sync parameters from ${rpc1}"
currentBlock=$(curl -s ${rpc1}/block | jq -r ".result.block.header.height"); \
syncFrom=$(($currentBlock - $syncRange)); \
syncFromHash=$(curl -s "${rpc1}/block?height=${syncFrom}" | jq -r .result.block_id.hash)

# check status/error codes
if [ $? -eq 0 ]
then
	# print the gotten parameters so user can verify
	echo "Current block height (should be a number without decimals): " ${currentBlock}
	echo "Trusted block height (should be current block - ${syncRange}): " ${syncFrom}
	echo "Trusted block hash (should be hash): " ${syncFromHash}
	echo
else
	echo "Failed to get state sync parameters, please check RPC's url. Exiting..."
	exit 1
fi

if [ "${prompts}" = true ]
then
	# make them verify they know something will be written to config
	echo "Please verify that the parameter values above look sane before proceeding (you can exit with ctrl+c)..."
	echo
	echo "Next, modifying ${configFile}:"
	echo "* current file will saved as .bak (possible existing .bak is overwritten)"
	echo "* the above parameter values will be set to state sync parameters"
	echo "* ech.world public nodes are added as persistent peers to the same file (so your node finds the snapshots)"
	echo "Type uppercase SET to proceed: "
	read setConfirmation
else
	# in non-interactive mode we gonna go ahead and SET
	setConfirmation="SET"
fi

echo

# validate
if [ "${setConfirmation}" = "SET" ]
then
	echo "Setting state sync parameters and adding persistent peers..."
else
	echo "Confirmation failed, setting parameters cancelled. Exiting..."
	exit 1
fi

# backup config.toml
cp $configFile $configFile.bak
if [ $? -eq 0 ]
then
	echo "Existing config.toml backed up to: ${configFile}.bak"
else
	echo "Failed to backup ${configFile}. Check errors above. Exiting..."
	exit 1
fi

# get the current persistent_peers from config.toml
persPeers=$(grep "persistent_peers " $configFile)

# if persistent_peers can't be found, exit here and make the user check that we are not doing anything stupid here...
if [ -z "$persPeers" ]
then
	echo
	echo "Error: persistent_peers not found at all in $configFile, please check that the file path is correct"
	echo "Add this line to the file manually if it's really the config.toml for the node: persistent_peers = \"\""
	echo "After that, run this script again. Exiting..."
	exit 1
fi

# if peer1 is not found in persistent_peers, add it
if [[ "$persPeers" != *"$peer1"* ]]
then
	echo "Adding ${peer1} to persistent peers..."
	sed -i "s/persistent_peers = \"[^\"]*/&,${peer1}/" $configFile
else
	echo "${peer1} was already in persistent peers: ok, no need to add it"
fi

# if peer2 is not found in persistent_peers, add it
if [[ "$persPeers =" != *"$peer2"* ]]
then
	echo "Adding ${peer2} to persistent peers..."
	sed -i "s/persistent_peers = \"[^\"]*/&,${peer2}/" $configFile
else
	echo "${peer2} was already in persistent peers: ok, no need to add it"
fi

# set state sync parameters to config.toml
echo "Setting state sync parameters..."
sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$rpc1,$rpc2\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$syncFrom| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$syncFromHash\"| ; \
s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"\"|" $configFile

# check status/error codes
if [ $? -eq 0 ]
then
	echo "State sync parameters set successfully."
	echo "State sync is enabled and node will start syncing from state sync snapshot when node is restarted/started"
	echo "Old config backed up to: ${configFile}.bak"
else
	echo "Failed to set state sync parameters. Exiting..."
	exit 1
fi

# best confirm the reset also
if [ "${prompts}" = true ]
then
	echo "Please verify there are no errors displayed above before proceeding"
	echo
	echo "Last chance to exit before removing existing data folder!"
	echo "If you proceed"
	echo "* the node will be stopped for the time it takes to reset the data folder"
	echo "* '$targetpath/data' will be emptied, node's addressbook removed and validator file partially reseted"
	echo "Type uppercase RESET to proceed:"
	read resetConfirmation
else
	# but if we are in non-interactive mode, we not gonna confirm anything from the user
	resetConfirmation="RESET"
fi

# validate
if [ "${resetConfirmation}" = "RESET" ]
then
	echo "Stopping node..."
else
	echo "Confirmation failed, data removal cancelled! Exiting..."
	exit 1
fi

# if node is running (is-active returns status 0), stop it here
systemctl is-active --quiet echelond && sudo systemctl stop echelond

# check if stopped (is-active should not return status 0)
systemctl is-active --quiet echelond
if [ $? -eq 0 ]
then
	echo "Failed to stop the node, data removal cancelled! Exiting..."
	exit 1
else
	echo "Node stopped successfully"
fi

# reset the node
echo "Resetting node..."
echelond tendermint unsafe-reset-all --home $targetpath

# check status/error codes
if [ $? -eq 0 ]
then
	echo "Node succesfully reset"
else
	echo "Failed to reset node!"
	echo "Please check error messages, fix accordingly and try again. Exiting..."
	exit 1
fi

# fire the node up
echo "Starting node..."
sudo systemctl start echelond

# check that node started (is-active should return 0)
systemctl is-active --quiet echelond
if [ $? -eq 0 ]
then
	echo "Node started successfully"
else
	echo "All done but failed to start node! Please check errors and try to start it manually."
fi

# all scripts reach the end, sooner or later
echo
echo "All done! Your node should start syncing from state sync snapshot. Few points for you to notice below"
echo
echo "CHECK NODE STATUS"
echo "Remember to check your node's logs to make sure everything is working: sudo journalctl -u echelond -f"
echo "Also, once echelond starts responding to queries, check that your node's current block height is near the network current height: echelond status"
echo
echo "DISABLE STATE SYNC"
echo "Please note: your config.toml has state sync as enabled"
echo "If you don't change the config and later reset your data folder, your node will try to start syncing from current trusted height which probably will fail"
echo "You don't need to keep state syncing enabled after your node has reached current network height"
echo "To disable state syncing (after your node is in sync with the rest of the network):"
echo "* open $configFile for editing"
echo "* find the attribute [statesync]"
echo "* under that, set enabled = false"
echo "* when echelond is restarted or started, state syncing will be disabled, node handles blocks normally"
echo
echo "ADDRESS BOOK"
echo "For faster peer exchange, you can download an up-to-date address book from ech.world easily"
echo "Go to your .echelond/config directory, make a backup of your existing addrbook.json for safety and then run:"
echo "wget https://ech.world/latest/addrbook.json -O addrbook.json"
echo
