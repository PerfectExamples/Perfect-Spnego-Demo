tar czvf /tmp/spng.tgz Sources Package.swift
scp /tmp/spng.tgz nut:/tmp
ssh nut "cd /tmp;rm -rf spng;mkdir spng;cd spng;tar xzvf ../spng.tgz;swift build"
