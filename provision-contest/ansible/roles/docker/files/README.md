# Loading containers from archives
Any container `.tar` files placed in a `containers-<host_type>` directory will be loaded as a container for the said host type.
The container will be tagged  with the relative path starting from `containers-<host_type>`, without the `.tar` file extension.
For example, the file `containers-glitchtip/glitchtip/glitchtip:v4.1.3.tar` will be loaded as a container tagged `glitchtip/glitchtip:v4.1.3` for the `glitchtip` host type.
Note that a nested directory structure is needed to tag containers which have both an organization and a container name.
