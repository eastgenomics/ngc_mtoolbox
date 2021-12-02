
#!/bin/bash
var='Hello.Bad.World!'
#echo $var
tmp=$var
echo $tmp | sed 's/.Bad././'