This image is configured as default and doesn't include any APIs

See the [Spiderfoot](https://github.com/smicallef/spiderfoot) Documentation for further details on usage

If you would like to keep data persistence across each session so you don't have to keep loading in APIs each time then you can configure the Kasm Workspace options as follows;

``
{
   "/path/to/host/folder/spiderfoot/":{
      "bind":"/var/lib/spiderfoot/",
      "mode":"rw",
      "uid": 1000,
      "gid": 1000,
      "required": true,
      "skip_check": false
   }
}
``
