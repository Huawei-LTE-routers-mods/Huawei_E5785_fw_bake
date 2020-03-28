#!/bin/sh

create_example() {
    echo '#!/bin/sh' > /online/scripts/example.sh
    echo 'echo text:Text example' >> /online/scripts/example.sh
    echo 'echo text:Argument: $1' >> /online/scripts/example.sh
    echo 'echo item:Menu item 1:ARG1' >> /online/scripts/example.sh
    echo 'echo item:Menu item 2:ARG2' >> /online/scripts/example.sh
    echo 'echo pagebreak:' >> /online/scripts/example.sh
    echo 'echo item:Menu item 3:ARG3' >> /online/scripts/example.sh
    echo 'echo this text is ignored' >> /online/scripts/example.sh
    echo 'echo item:Menu item 4:ARG4' >> /online/scripts/example.sh
    echo 'echo text:' >> /online/scripts/example.sh
    echo 'echo text:To make custom' >> /online/scripts/example.sh
    echo 'echo text:scripts please' >> /online/scripts/example.sh
    echo 'echo text:look at my source' >> /online/scripts/example.sh
    chmod 755 /online/scripts/example.sh
}

print_scripts() {
    for script in *.sh; do
        FIRST="$(echo -n "${script:0:1}" | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/')"
        REST="$(echo -n "${script:1}" | sed 's/_/ /g' | sed 's/.sh$//')"
        echo "item:${FIRST}${REST}:/online/scripts/$script"
    done
}

mkdir -p /online/scripts
chmod 755 /online/scripts/*.sh

if [ $? -ne 0 ]; then
    if [ ! -f /online/scripts/example.sh ]; then
        create_example
    fi
fi

echo "text:In /online/scripts:"
cd /online/scripts && print_scripts
