#!/bin/bash

# Массив серверов с паролем
PACKAGES=(
    "apache2"
    "mysql-common"
)

SERVERS=(
    "192.168.1.7:abc123"
    "192.168.1.10:dif456"
)

# функция установки пакета на сервер
function installPkg {
    package=$1
    ssh ${ip} -l root "apt install $package" > /dev/null 2>&1
    if [ "$?" = "0" ]; then
        echo "Seccess install $package to $ip"
    else
        echo "Error install $package"

        # обрезаем и получаем сам пакет без версии
        package=$( echo $package | cut -d '=' -f 1)

        #получаем текущую версию пакета
        getInstalledPkgVer=$(dpkg -s $package | grep 'Version' | cut -d ' ' -f 2)

        # в случае ошибки, получаем последнюю рабочую версию пакета и устанавливаем
        getLastPkgVer=$(ssh ${ip} -l root "apt-cache show $package | grep 'Version' | sed -n 1p | cut -d ' ' -f 2")

        installPkg "$package=$getLastPkgVer"
    fi
}

# проходимся по массиву
for srv in ${!SERVERS[@]}
do
    # преобразуем элемент массива в новый массив через разделитель
    IFS=':' read -ra SERV <<< "${SERVERS[$srv]}"

    # объявляем в переменные элементы массива SERV
    ip=${SERV[0]}
    pass=${SERV[1]}

    # проверяем можем ли мы подключится к серверу по ключу
    ssh -o passwordauthentication=no -i $HOME/.ssh/id_rsa root@${ip} : 2>/dev/null
    if [ "$?" = "0" ]; then
        # делаем update на удалённом сервере
        ssh ${ip} -l root "apt update" > /dev/null 2>&1
        if [ "$?" = "0" ]; then
            echo "Update package to $ip"

            # проходимся по списку пакетов
            for pkg in ${!PACKAGES[@]}
            do  
                package=${PACKAGES[$pkg]}
                # вызываем функцию в которой происходит установка
                installPkg $package
            done

        else
            echo "Error update package to $ip"
        fi
    else
        # если нет, настраиваем связь

        #знакомимся с сервером, добавляем в довеоренные
        ssh-keyscan -H ${ip} >> ~/.ssh/known_hosts > /dev/null 2>&1
        # добавляем наш публичный ключ на сервер
        cat $HOME/.ssh/id_rsa.pub | sshpass -p "${pass}" ssh root@${ip} 'mkdir -p $HOME/.ssh && cat >> ~/.ssh/authorized_keys' > /dev/null 2>&1
        if [ "$?" = "0" ]; then
            echo "key successfully added to $ip"
        else
            echo "Authorization Error"
        fi
    fi
done