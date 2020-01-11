. ./lib.sh

msg_box "It seems like the port ${1} is closed. This could
happend when your ISP has blocked the port, or that the port
isn't open.

If you are 100% sure the port ${1} is open you can now choose
to continue. There are no guarantees that it will work anyway
though,since Let's Encrypt depend on that the port ${1} is
open and accessible from outside your network."
