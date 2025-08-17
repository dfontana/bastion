# SSHD Test Server

Contains:
- A docker file + compose to spin up an sshd instance
- It's mounted to the auth log and authorized-keys files in this repo
- There are some test keys you generated, obviously for testing purposes
- You can see the root account password + sshuser account password in the dockerfile.
- An `sshd_config` file where you can tweak the settings && restart the server to see how it affects things
