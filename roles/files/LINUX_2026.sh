#!/bin/bash

## 파일 배포날짜로 최종적으로 수정할 것(ex. 210224)
UPDATE_DATE="260330"

if [ `id | grep "uid=0" | wc -l` -eq 0 ] ; then
	echo ": This Script need root permission."
	exit
fi

ENCODING="utf-8"
LANG=C 

# OS Type, Version
OS_NAME=`uname -a | awk '{print $1}'`
HOSTNAME=`uname -a | awk '{print $2}'`

IPADDR_LIST=`ifconfig -a 2>/dev/null | awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}' | grep -v "127.0.0.1" | grep -v "^$"`
if [ -z "${IPADDR_LIST}" ]; then
	IPADDR_LIST=`ip -4 addr show 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]}' | grep -v "127.0.0.1" | grep -v "^$"`
fi

if [ -f /etc/redhat-release ] ; then
  OS_VERSION=`cat /etc/redhat-release | awk '{print $3}'`
elif [ `uname -a | grep -i "ubuntu" | wc -l` -gt 0 ]; then
  OS_VERSION=`uname -a | awk '{print $4}'`
fi

if [ -f /etc/redhat-release ]; then
  SW_INFO=`cat /etc/redhat-release | sed 's/release //'`
elif [ -f /etc/os-release ]; then
  SW_INFO=`cat /etc/os-release | grep "PRETTY_NAME" | awk -F= '{print $2}' | sed 's/"//g'`
else
  SW_INFO=`uname -v`
fi


## 스크립트 구동 중에 각 태그별 필요한 내용 저장하는 파일들 설정("Standard:양호/취약 기준", "Status:해당 시스템 현황")
mkdir ksecure 2>/dev/null
chmod 700 ksecure
STANDARD_FILE="ksecure/STANDARD"
STATUS_FILE="ksecure/STATUS"
RESULTDIR="LINUX^${HOSTNAME}^${UPDATE_DATE}"
mkdir "LINUX^${HOSTNAME}^${UPDATE_DATE}" 2>/dev/null
chmod 700 "LINUX^${HOSTNAME}^${UPDATE_DATE}"

## 쉡 스크립트 구동시 쉘창에 출력시기기 위한 부분
SH_HEADER() {
	echo "======================================================================="
	echo " ██╗  ██╗    ███████╗███████╗ ██████╗██╗   ██╗██████╗ ███████╗"
	echo " ██║ ██╔╝    ██╔════╝██╔════╝██╔════╝██║   ██║██╔══██╗██╔════╝"
	echo " █████╔╝     ███████╗█████╗  ██║     ██║   ██║██████╔╝█████╗"
	echo " ██╔═██╗     ╚════██║██╔══╝  ██║     ██║   ██║██╔══██╗██╔══╝"
	echo " ██║  ██╗    ███████║███████╗╚██████╗╚██████╔╝██║  ██║███████╗"
	echo " ╚═╝  ╚═╝    ╚══════╝╚══════╝ ╚═════╝ ╚═════╝╚═╝  ╚═╝╚══════╝"
	echo ""
	echo "Copyright 2026 K-Secure. All right Reserved"
	echo "======================================================================="
	echo "-------------------------------------------------------------------"
	echo "LINUX ${SW_INFO}"
	date
	echo "System HostName : ${HOSTNAME}"
	echo "System IP Address :"
	for IP in ${IPADDR_LIST}; do
		echo ${IP}
	done
	echo "-------------------------------------------------------------------"

	# Apache 서비스가 구동 중이면 모든 설정 파일을 가지고 오도록 설정
	# Apache 서버 IP 주소는 담당자가 직접 입력하도록 코드 수정
	
	#echo " 2. Is the web service running? [1(Apache), 2(WebtoB), 3(OHS), 4(NginX), 5(JEUS), 6(Tomcat), 0(no)]"
	#read Running_WebService
	#echo ""
	
	if [ `echo $Running_WebService | egrep -i "0|1|2|3|4|5|6" | wc -l` -eq 0 ]; then
		while [ 1 ]
		do
			echo " 2. Is the web service running? [1(Apache), 2(WebtoB),3(OHS), 4(NginX), 5(JEUS), 6(Tomcat), 0(no)]"
			read Running_WebService
			echo ""
			
			if [ `echo $Running_WebService | egrep -i "0|1|2|3|4|5|6" | wc -l` -gt 0 ]; then
				break
			fi
		done
	fi
	# Apache Start
	if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
		 
		echo " 2-1. Input the Apache Home directory path. "
		read Home_Dir
		echo ""
		
		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo $Home_Dir | grep -i "^/" | wc -l` -eq 0 ]; then
			Home_Dir="/${Home_Dir}"
		fi
			
		conf_D=`ls -d ${Home_Dir}/conf 2>/dev/null`

		## 입력받은 Home_Dir에 httpd.conf 파일이 존재하는지 확인
		httpd_F=`find ${Home_Dir} /etc/apache2 -type f \( -name 'httpd.conf' -o -name 'apache2.conf' \) 2>/dev/null`

		## 아래 두개의 변수의 값이 하나라도 없으면 Home_Dir 경로가 잘못되거나, 설정파일이 존재하지 않는 경우(vhost는 필수 아님)
		## 설정파일이 존재하는 홈디렉터리 경로를 다시 입력 받아야 한다.
		if [ `echo ${httpd_F} | grep apache2.conf` ]; then
			echo ""
		elif [ `echo "${httpd_F}" | tr ' ' '\n' | grep '/etc/httpd.conf'` ]; then
			echo ""
		elif [ "${conf_D}" -a "${httpd_F}" ]; then
			echo ""
		else
			echo "***********************************************************************"
			echo "The Answer is incorrect(HOME Dir or CONF file does not exist). "
			echo "If you don't know, write down the command."
			echo "***********************************************************************"
			echo ""
			echo "ex) find / -type f -name httpd.conf"
			echo ""
			echo ""
			exit
		fi
		
		echo " 2-2. Input the Vhost_Name Name. [Default : main]"
		read Vhost_Name
		echo ""

		# 만약 입력값이 존재하지 않을 경우, main으로 Vhost_Name 치환
		# 입력값이 실제 사용 중인 Vhost 인지는 검증하지 않음
		if [ ! "${Vhost_Name}" ]; then
			Vhost_Name="main"
		fi
		ResultFile_Name="Apache^"`hostname`"(${Vhost_Name})^ksecure^"`date +%y%m%d`".txt"
		
		{
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : Apache(Unix)" 
		echo "VHOST NAME : "$Vhost_Name 
		echo ""

		# HDR/bin/httpd 경로가 환경변수로 등록된 경우, 명령어 실행 가능
		# 그러나 간혹, httpd 가 홈디렉터리에 존재하지 않을 수도 있어 버전이 출력되지 않을 수도 있다. 
		echo "[SW Info]"
		if ${Home_Dir}/bin/httpd -v 2>/dev/null; then
			echo ""
		elif ${Home_Dir}/sbin/httpd -v 2>/dev/null; then
			echo ""
		elif apache2 -v 2>/dev/null; then
			echo ""
		fi
		echo ""

		# 서버 IP 정보 출력
		# OS 별 IP 명령어가 다르므로 1차적으로 "ip addr" 하고, 에러나면 "netstat -in"으로 검색 
		echo "[IP Info]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 
		
		echo "=======================================================================" 
		echo "*** Systemctl -V ***" 
		echo "=======================================================================" 
		if ${Home_Dir}/bin/apachectl -V 2>/dev/null; then
			echo ""
		elif ${Home_Dir}/sbin/apachectl -V 2>/dev/null; then
			echo ""
		elif /usr/sbin/apachectl -V 2>/dev/null; then
			echo ""
		fi
		
		echo "=======================================================================" 
		echo "*** Sample Directory ***" 
		echo "=======================================================================" 
		## 샘플 디렉터리페이지 존재여부 확인 
		ls -adl "${Home_Dir}/sample"
		ls -adl "${Home_Dir}/samples"
		ls -adl "${Home_Dir}/example"
		ls -adl "${Home_Dir}/examples"
		ls -adl "${Home_Dir}/manual"
		ls -adl "${Home_Dir}/manuals"
		ls -adl "${Home_Dir}/welcome"
		ls -adl "${Home_Dir}/docs"
		ls -adl "${Home_Dir}/test"
		ls -adl "${Home_Dir}/cgi-bin"
		echo "" 

		echo "=======================================================================" 
		echo "*** Home_Dir & Reference File Permission ***" 
		echo "=======================================================================" 
		# HOME 디렉터리 권한 확인
		echo "[ Home Dir - WES_011 ]"
		ls -dl ${Home_Dir}
		echo ""

		# 홈디렉터리에 존재하는 httpd.conf 파일 권한 출력
		echo "[ httpd.conf - WES_001 ~ WES_010, WES_012 ]" 
		for file in ${httpd_F}; do
			ls -l ${file} 
		done
		echo ""

		# 홈디렉터리에 존재하는 vhost.conf 파일 권한 출력(필수가 아니므로 없어도 됨)
		vhost_F=`find ${Home_Dir} -type f -name 'vhost.conf'`

		echo "[ vhost.conf ]" 
		if [ "${vhost_F}" ]; then
			for file in ${vhost_F}; do
				ls -l ${file} 
			done
			echo ""
		else
			echo "File NOT FOUND"
			echo ""
		fi

		echo "=======================================================================" 
		echo "*** Config File Contents ***" 
		echo "=======================================================================" 
		# 홈디렉터리에 존재하는 httpd.conf 내용 출력(여러개일 경우, 모두 출력)
		for file in ${httpd_F} ${vhost_F}; do
			for filepath in ${file}; do
				echo "[ ${filepath} ]" 
				cat ${filepath}
				echo ""
			done
			echo "=======================================================================" 
			echo "" 
		done

		# 홈디렉터리에 존재하는 vhost.conf 내용 출력(여러개일 경우, 모두 출력)
		# for file in ; do
			# echo "[ ${file} ]" 
			# cat ${file} 
			# echo "=======================================================================" 
			# echo "" 
		# done

		echo "========================= complete!! =================================="
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1
		#Apache End

	#WebtoB Start
	elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
		## 질의문 총 3개(Install_Dir, Conf_Name, Vhost_Name)
		echo " 2-1. Input the WebtoB Install directory path."
		read Install_Dir
		echo ""
		
		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo $Install_Dir | grep -i "^/" | wc -l` -eq 0 ]; then
			Install_Dir="/${Install_Dir}"
		fi
			
		## 입력받은 Install_Dir에 conf 디렉터리가 존재해야 진짜 설치디렉터리이다.
		## find ${Install_Dir} -type d -name 'conf*'으로 하지 않은 이유는
		## 입력값이 설치디렉터리가 아닌 최상위 경로로 입력하면 무조건 참값으로 나오기때문
		conf_D=`ls -d ${Install_Dir}/config 2>/dev/null`

		## Install 디렉터리에 config 디렉터리가 존재하는 지 확인
		## config 디렉터리가 없으면 설치디렉터리 경로가 틀린거임
		if [ "${conf_D}" ]; then
			while [ 1 ]
			do		
				echo " 2-2. Input the Config File Name. [Default : http.m]"
				read Conf_Name
				echo ""
				
				# 만약 입력값이 존재하지 않을 경우, http.m으로 Conf_Name 치환
				if [ ! "${Conf_Name}" ]; then
					Conf_Name="http.m"
				fi
				
				## 입력받은 Install_Dir에 Conf_Name 파일이 존재하는지 확인
				http_F=`find ${Install_Dir} -type f -name "${Conf_Name}" 2>/dev/null`
				
				
				# 입력받은 설정파일이 존재하는지 확인(없으면 오류 메시지 출력)
				if [ "${http_F}" ]; then
					break
				else
					echo "***********************************************************************"
					echo "The Answer is incorrect(CONF file does not exist). "
					echo "If you don't know, write down the command."       
					echo "***********************************************************************"
					echo "> ls ${Install_Dir}/config"
					echo ""
					ls ${Install_Dir}/config
					echo "***********************************************************************"
					echo ""
				fi
			done
		else
			echo "***********************************************************************"
			echo "The Answer is incorrect(Install Dir does not exist). "
			echo "If you don't know, write down the command."       
			echo "***********************************************************************"
			echo ""
			echo "ex) find / -type f -name http.m"
			echo ""
			echo ""
			exit
		fi

		echo ""
		echo " 2-3. Input the Vhost Name. [Default : main]"
		read Vhost_Name
		echo ""

		# 만약 입력값이 존재하지 않을 경우, main으로 Vhost_Name 치환
		if [ ! "${Vhost_Name}" ]; then
			Vhost_Name="main"
		fi

		## 저장파일 지정
		ResultFile_Name="WebtoB^"`hostname`"(${Vhost_Name})^ksecure^"`date +%y%m%d`".txt"

		{ ## 시간, 호스트네임 등 기본 정보 저장(괄호로 묶어서 한번에 저장시키자)
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : WebtoB(Unix)" 
		echo "ConfigFile NAME : "$Conf_Name 
		echo "VHOST NAME : "$Vhost_Name 
		echo ""

		## 서비스 버전정보등 출력
		echo "[SW Info]"
		${Install_Dir}/bin/wscfl -version
		echo ""

		## 서버 IP 정보 출력
		## OS 별 IP 명령어가 다르므로 1차적으로 "ip addr"(유닉스 기본) 하고, 에러나면 "netstat -in"으로 검색 
		echo "[IP Info]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 


		echo "=======================================================================" 
		echo "*** Sample Directory ***" 
		echo "=======================================================================" 
		## 샘플 디렉터리페이지 존재여부 확인 
		ls -adl "${Install_Dir}/sample"
		ls -adl "${Install_dDir}/samples"
		ls -adl "${Install_Dir}/example"
		ls -adl "${Install_Dir}/examples"
		ls -adl "${Install_Dir}/manual"
		ls -adl "${Install_Dir}/manuals"
		ls -adl "${Install_Dir}/welcome"
		ls -adl "${Install_Dir}/test"
		echo "" 

		echo "=======================================================================" 
		echo "*** Install_Dir Permission & Reference File ***" 
		echo "=======================================================================" 
		# Install, conf 디렉터리 권한 확인
		echo "[ Install Dir - WES_009]"
		ls -dl ${Install_Dir} # 설치 디렉터리 자체 권한
		echo ""

		# Log 디렉터리 권한 확인(log 아니면 logs로 확인)
		echo "[ Log Dir - WES_014 ]"
		if ls -dl "${Install_Dir}/log" 2>/dev/null; then
			echo ""
		elif ls -dl "${Install_Dir}/logs" 2>/dev/null; then
			echo ""
		else
			echo "${Install_Dir}/log(s) Directory not Found."
			echo "!!!Check the Log Dir Path in conf_file!!!"
			echo ""
		fi

		## 설치디렉터리에 존재하는 설정파일(진단에 필요한 것만) 목록 출력
		echo "[ ${Conf_Name} - WES_001 ~ WES_011, WES_013 ]" 
		for file in ${http_F}; do
			ls -l ${file} 
		done
		echo ""

		echo "=======================================================================" 
		echo "*** Config File Contents ***" 
		echo "=======================================================================" 
		## 설정파일 내용 출력(모두 출력)
		for file in ${http_F}; do
			echo "[ ${file} ]" 
			cat ${file} 
			echo "=======================================================================" 
			echo "" 
		done

		echo "========================= complete!! =================================="
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1
		#Webtob End
	
	#OHS Start
	elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
		echo "(1/3) Input the Oracle HTTP Server Instance(11g version) or Domain(12c version) directory path. "
		echo "(ex) /home/oracle/Middleware/Oracle_WT1/instances/instance1"
		echo "(ex) /home/oracle/fmw-12/user_projects/domains/base_domain"
		read Install_Dir


		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo ${Install_Dir} | grep -i "^/" | wc -l` -eq 0 ]; then
			Install_Dir="/${Install_Dir}"
		fi


		## 입력받은 경로가 '/'로 끝나는지 확인 (있을 경우 제거)
		if [ `echo ${Install_Dir: -1} | grep -i "/" | wc -l` -gt 0 ]; then
			Install_Dir=${Install_Dir%/}
		fi


		## 입력받은 Install_Dir에 conf 디렉터리가 존재해야 진짜 설치디렉터리이다.
		## find ${Install_Dir} -type d -name 'conf*'으로 하지 않은 이유는
		## 입력값이 설치디렉터리가 아닌 최상위 경로로 입력하면 무조건 참값으로 나오기때문
		conf_D=`ls -d ${Install_Dir}/config 2>/dev/null`


		## 입력받은 Install_Dir에 httpd.conf 파일이 존재하는지 확인
		httpd_F=`find ${Install_Dir}/config -type f -name 'httpd.conf' 2>/dev/null`


		## 아래 두개의 변수의 값이 하나라도 없으면 Install_Dir 경로가 잘못되거나, 설정파일이 존재하지 않는 경우(vhost는 필수 아님)
		## 설정파일이 존재하는 설치디렉터리 경로를 다시 입력 받아야 한다.
		if [ "${conf_D}" -a "${httpd_F}" ]; then
			echo ""
		else
			echo "***********************************************************************"
			echo "The Answer is incorrect(Instance, Domain Dir or CONF file does not exist). "
			echo "If you don't know, write down the command."
			echo "***********************************************************************"
			echo ""
			echo "ex) find / -type f -name 'httpd.conf'"
			echo "" 
			echo ""

			exit
		fi


		## 입력받은 경로에서 Oracle_HOME 디렉터리 추출
		## 입력받은 경로에서 "/" 의 개수만큼 ../를 진행
		## 그 후 /ohs/bin/httpd 파일이 존재하면, 해당 디렉터리가 Oracle_HOME라 판단
		count=`echo ${Install_Dir} | grep -o "/" | wc -l`
		Oracle_HOME=${Install_Dir}

		for i in `seq 1 1 ${count}`
		do
			if [ "`ls -l ${Oracle_HOME}/ohs/bin/httpd 2>/dev/null`" ]; then
				break
			else
				Oracle_HOME=${Oracle_HOME%/*}
			fi
		done


		## httpd를 사용하기 위한 동적 라이브러리 변수 설정
		export buffer=$LD_LIBRARY_PATH
		export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${Oracle_HOME}/ohs/lib:${Oracle_HOME}/lib:${Oracle_HOME}/oracle_common/lib

		OHS_Version=`${Oracle_HOME}/ohs/bin/httpd -v`




		## Component 이름 받기
		echo "(2/3) Input the Component Name."
		read Component_Name

		## 대상 Component의 httpd.conf 파일만 받아오게 변경
		httpd_F=`echo ${httpd_F} | grep /${Component_Name}/`

		if [ "${httpd_F}" ]; then
			echo ""
		else
			if [ `echo ${OHS_Version} | grep "12." | wc -l` -gt 0 ]; then
				# 12c
				echo "***********************************************************************"
				echo "The Answer is incorrect(Component Name). "
				echo "If you don't know, See below"
				echo "***********************************************************************"
				echo ""
				echo "> ls ${Install_Dir}/config/fmwconfig/components/OHS/instances/"
				echo "" 
				ls -l ${Install_Dir}/config/fmwconfig/components/OHS/instances/ 2>/dev/null
				echo ""
				echo "***********************************************************************"
				exit
			else
				# 11g
				## 11버전의 경우, 구조 파악이 아직 덜되어서 어떤 구조를 가지고 있을 지 모르기에 component 경로보단 find로
				## httpd.conf 파일을 통해 중간 component 경로 파악
				echo "***********************************************************************"
				echo "The Answer is incorrect(Component Name). "
				echo "If you don't know, See below"
				echo "***********************************************************************"
				echo ""
				echo "> find ${Install_Dir}/config | grep -type f -name 'httpd.conf' 2>/dev/null"
				echo "" 
				find ${Install_Dir}/config -type f -name 'httpd.conf' 2>/dev/null
				echo ""
				echo "***********************************************************************"
				exit		
			fi
			
		fi


		## Vhost 진단 시, Vhost 이름 가져오기
		echo "(3/3) Input the Vhost Name.(Default:main)"
		read Vhost_Name

		# 만약 입력값이 존재하지 않을 경우, main으로 Vhost_Name 치환
		# 입력값이 실제 사용 중인 Vhost 인지는 검증하지 않음
		if [ ! "${Vhost_Name}" ]; then
			Vhost_Name="main"
		fi


		## 저장파일 지정
		ResultFile_Name="OHS^"`hostname`"(${Vhost_Name})^ksecure^"`date +%y%m%d`".txt"

		{ # 시간, 호스트네임 등 기본 정보 저장(괄호로 묶어서 한번에 저장시키자)
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : OHS(Unix)" 
		echo "VHOST NAME : "${Vhost_Name} 
		echo ""

		# HDR/bin/httpd 경로가 환경변수로 등록된 경우, 명령어 실행 가능
		# 그러나 간혹, httpd 가 설치디렉터리에 존재하지 않을 수도 있어 버전이 출력되지 않을 수도 있다. 
		echo "[SW Info]"

		# httpd 를 사용하기 위해 OHS 설치 디렉터리 내 동적 라이브러리 경로 지정

		echo ${OHS_Version}
		echo ""

		# 서버 IP 정보 출력
		# OS 별 IP 명령어가 다르므로 1차적으로 "ip addr" 하고, 에러나면 "netstat -in"으로 검색 
		echo "[IP Info]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 


		echo "=======================================================================" 
		echo "*** Sample Directory ***" 
		echo "=======================================================================" 
		## 샘플 디렉터리페이지 존재여부 확인 
		ls -adl "${Oracle_HOME}/sample"
		ls -adl "${Oracle_HOME}/samples"
		ls -adl "${Oracle_HOME}/example"
		ls -adl "${Oracle_HOME}/examples"
		ls -adl "${Oracle_HOME}/manual"
		ls -adl "${Oracle_HOME}/manuals"
		ls -adl "${Oracle_HOME}/welcome"
		ls -adl "${Oracle_HOME}/test"
		echo "" 

		echo "=======================================================================" 
		echo "*** Install_Dir & Reference File Permission ***" 
		echo "=======================================================================" 
		# Install 디렉터리 권한 확인
		echo "[ Install Dir - WES_009 ]"
		ls -dl ${Oracle_HOME}
		echo ""


		## httpd.conf 개수 확인 및 차이 유무 확인
		httpd_count=`echo ${httpd_F} | grep -o 'httpd.conf' | wc -l`
		dif_flag=0

		if [ `echo ${httpd_count}` -gt 1 ]; then
			# 2개
			if [ `diff ${httpd_F} | wc -l` -gt 1 ]; then
				# 두 httpd.conf 파일은 차이가 존재
				dif_flag=1
			fi
		else
			#1개
			echo ""
		fi

		## Log 디렉터리 권한 확인

		if [ ${dif_flag} -eq 0 ]; then
			# httpd.conf 일치
			buf=`echo ${httpd_F} | awk '{print $1;}'`
			if [ `cat $buf | grep -v "^#" | grep -i "CustomLog" | grep -i "rotatelogs" | wc -l` -gt 0 ]; then
				# rotatelogs 사용 중
				CustomLog=`cat ${buf} | grep -v "^#" | grep -i "CustomLog" | awk '{print $3;}'`
			else
				CustomLog=`cat ${buf} | grep -v "^#" | grep -i "CustomLog" | awk '{print $2;}'`
			fi
		else
			for file in ${httpd_F}; do
				if [ `echo ${file} | grep -i 'instance' | grep -v 'backup' | wc -l` -gt 0 ]; then
					buf=${file}
				fi
			done
			
			if [ `cat $buf | grep -v "^#" | grep -i "CustomLog" | grep -i "rotatelogs" | wc -l` -gt 0 ]; then
				# rotatelogs 사용 중
				CustomLog=`cat ${buf} | grep -v "^#" | grep -i "CustomLog" | awk '{print $3;}'`
			else
				CustomLog=`cat ${buf} | grep -v "^#" | grep -i "CustomLog" | awk '{print $2;}'`
			fi
		fi

		## Oracle Alias 변수 치환
		CustomLog=${CustomLog/'${ORACLE_INSTANCE}'/${Install_Dir}}
		CustomLog=${CustomLog/'${COMPONENT_TYPE}'/OHS}
		CustomLog=${CustomLog/'${COMPONENT_NAME}'/${Component_Name}}
		CustomLog=`dirname ${CustomLog}`

		echo "[ Log Dir - WES_014 ]"
		if ls -dl "${CustomLog}" 2>/dev/null; then
			echo ""
		elif ls -dl "${CustomLog}" 2>/dev/null; then
			echo ""
		else
			echo "${CustomLog} Directory not Found."
			echo "!!!Check the Log Dir Path in conf_file!!!"
			echo ""
		fi

		# 설치디렉터리에 존재하는 httpd.conf 파일 권한 출력
		echo "[ httpd.conf - WES_001 ~ WES_011, WES_013 ]" 
		for file in ${httpd_F}; do
			ls -l ${file} 
		done
		echo ""

		# 설치디렉터리에 존재하는 vhost.conf 파일 권한 출력(필수가 아니므로 없어도 됨)
		vhost_F=`find ${Install_Dir} -type f -name 'vhost.conf'`

		echo "[ vhost.conf - WES_002 ~ WES_011, WES_013 ]" 
		if [ "${vhost_F}" ]; then
			for file in ${vhost_F}; do
				ls -l ${file} 
			done
			echo ""
		else
			echo "File NOT FOUND"
			echo ""
		fi

		echo "=======================================================================" 
		echo "*** Config File Contents ***" 
		echo "=======================================================================" 
		# 설치디렉터리에 존재하는 httpd.conf 내용 출력(여러개일 경우, 모두 출력)

		if [ ${dif_flag} -eq 1 ]; then
			for file in ${httpd_F} ${vhost_F}; do
				echo "[ ${file} ]" 
				cat ${file} 
				echo "=======================================================================" 
				echo "" 
			done
		else
			for file in ${httpd_F}; do
				if [ `echo ${file} | grep -i 'instance' | grep -v 'backup' | wc -l` -gt 0 ]; then
					buf=${file}
				fi
			done
			for file in ${buf} ${vhost_F}; do
				echo "[ ${file} ]" 
				cat ${file} 
				echo "=======================================================================" 
				echo "" 
			done
		fi

		echo "========================= complete!! =================================="
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1


		# 스크립트 종료 메시지 화면에 출력
		echo "========================= complete!! =================================="
	#OHS END
	
	
	#NginX Start
	elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
		## 질의문 총 2개(Install_Dir, Port_Number)
		echo "(1/2) Input the Nginx Install directory path."
		read Install_Dir

		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo $Install_Dir | grep -i "^/" | wc -l` -eq 0 ]; then
			Install_Dir="/${Install_Dir}"
		fi

		if [ -e $Install_Dir/nginx.conf ]
			then
				echo ""
			else
				echo "***********************************************************************"
				echo "The Answer is incorrect(Install Dir does not exist). "
				echo "If you don't know, write down the command."
				echo "***********************************************************************"
				echo ""
				echo "ex) find / -type f -name 'nginx.conf'"
				echo ""
				echo ""
				exit
		fi

		echo "(2/2) Input the Port Number. (Default:80)"
		read port_num

		# 만약 입력값이 존재하지 않을 경우, port_num 80으로 치환
		# 입력값이 실제 사용 중인 Vhost 인지는 검증하지 않음
		if [ ! "${port_num}" ]; then
			port_num="80"
		fi

		## 저장파일 지정
		ResultFile_Name="Nginx^"`hostname`"(${port_num})^ksecure^"`date +%y%m%d`".txt"

		{ # 시간, 호스트네임 등 기본 정보 저장(괄호로 묶어서 한번에 저장시키자)
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : Nginx(Unix)"
		echo "VHOST NAME : $port_num (Port_Number)"
		echo ""

		#버전 정보 출력
		echo "[ SW Info ] "
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1
		nginx -v 2>&1 | grep -i nginx >> "${RESULTDIR}/${ResultFile_Name}"
		{ 
		echo ""

		# 서버 IP 정보 출력
		# OS 별 IP 명령어가 다르므로 1차적으로 "ip addr" 하고, 에러나면 "netstat -in"으로 검색 
		echo "[IP Info]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 

		echo "=======================================================================" 
		echo "*** Sample Directory ***" 
		echo "=======================================================================" 
		## 샘플 디렉터리페이지 존재여부 확인 
		ls -adl "${Install_Dir}/sample"
		ls -adl "${Install_Dir}/samples"
		ls -adl "${Install_Dir}/example"
		ls -adl "${Install_Dir}/examples"
		ls -adl "${Install_Dir}/manual"
		ls -adl "${Install_Dir}/manuals"
		ls -adl "${Install_Dir}/welcome"
		ls -adl "${Install_Dir}/test"
		echo ""

		echo "=======================================================================" 
		echo "*** Install_Dir & Reference File Permission ***" 
		echo "=======================================================================" 
		# Install 디렉터리 권한 확인
		echo "[ Install Dir - WES_009 ]"
		ls -dl ${Install_Dir}
		echo ""

		# Log 디렉터리 권한 확인(log 아니면 logs로 확인)
		echo "[ Log Dir - WES_014 ]"
		if ls -dl "/var/log/nginx" 2>/dev/null; then
			echo ""
		elif ls -dl "/var/logs/nginx" 2>/dev/null; then
			echo ""
		else
			echo "/var/log(s) Directory not Found."
			echo "!!!Check the Log Dir Path in conf_file!!!"
			echo ""
		fi

		# 설치디렉터리에 존재하는 conf 파일 권한 출력
		echo "[ nginx.conf ]" 
		ls -l "${Install_Dir}/nginx.conf"

		echo ""
		echo "=======================================================================" 
		echo "*** Config File Contents ***"
		echo "=======================================================================" 
		echo "[ $Install_Dir/nginx.conf ]" 
		cat $Install_Dir/nginx.conf  

		echo "======================================================================="
		echo ""
		echo "========================= complete!! =================================="
		} >> "${RESULTDIR}/${ResultFile_Name}" 2>&1
		#NginX End
	
	# JEUS Start
	elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
		## 질의문 총 2개(Install_Dir, Domain)
		echo "(1/2) Input the Jeus Install directory path."
		read Install_Dir
		echo ""
		
		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo $Install_Dir | grep -i "^/" | wc -l` -eq 0 ]; then
				Install_Dir="/${Install_Dir}"
		fi
		
		## 입력받은 Install_Dir에 config 디렉터리(6 이하), domains  디렉터리(7 이상) 존재해야 진짜 설치디렉터리이다.
		## find ${Install_Dir} -type d -name 'conf*'으로 하지 않은 이유는
		## 입력값이 설치디렉터리가 아닌 최상위 경로로 입력하면 무조건 참값으로 나오기때문
		conf6_D=`ls -d ${Install_Dir}/config 2>/dev/null`
		conf7_D=`ls -d ${Install_Dir}/domains 2>/dev/null`
		
		
		## Install 디렉터리에 config 디렉터리가 존재하는 지 확인
		## config 디렉터리가 없으면 설치디렉터리 경로가 틀린거임
		if [ "${conf6_D}" -o "${conf7_D}" ]; then
			while [ 1 ]
			do
				echo "(2/2) Input the Domain Name."
				read Domain
				## 만약 입력값이 존재하지 않을 경우, null로 Domain 치환
				if [ ! "${Domain}" ]; then
					Domain="null"
				fi	
		
				# 버전별 상이해서 조건문 선언
				if [ "${conf6_D}" ]; then
					Domain_D="${conf6_D}/${Domain}"
				
					## 입력받은 Domain에 JEUSMain.xml, accounts.xml, WEBMain.xml 파일이 존재하는지 확인
					JEUSMain_F=`find ${Domain_D}/ -type f -name "JEUSMain.xml"`
					accounts6_F=`find ${Domain_D}/security -type f -name "accounts.xml";`
				else
					Domain_D="${conf7_D}/${Domain}"
	
					## 입력받은 Domain에 domain.xml, accounts.xml 파일이 존재하는지 확인
					domain_F=`find ${Domain_D}/config/ -type f -name "domain.xml"`
					accounts7_F=`find ${Domain_D}/config/security/SYSTEM_DOMAIN/ -type f -name "accounts.xml"`
				fi
				## 아래 변수의 값이 하나라도 없으면 Domain 이름이 잘못되거나, 설정파일이 존재하지 않는 경우
				## 설정파일이 존재하는 Domain를 다시 입력 받아야 한다.
				if [ "${JEUSMain_F}" -a "${accounts6_F}" ] || [ "${domain_F}" -a "${accounts7_F}" ]; then
					break
				else
					echo ""
					echo "***********************************************************************"
					echo "The Answer is incorrect(Domain Name or CONF file does not exist). "
					echo "If you don't know, See below.         "
					echo "***********************************************************************"
					echo "> ls ${Install_Dir}/config  or  ls ${Install_Dir}/domains"
					echo ""
					ls -l ${conf6_D} ${conf7_D} 2>/dev/null
					echo ""
					echo "***********************************************************************"
				fi
			done

		else
			echo "***********************************************************************"
			echo "The Answer is incorrect(Install Dir does not exist). "
			echo "If you don't know, write down the command."
			echo "***********************************************************************"
			echo ""
			echo "ex) find / -type d -name '*jeus*'"
			echo ""
			echo ""
			exit
		fi
	
		## 저장파일 지정
		ResultFile_Name="Jeus^"`hostname`"(${Domain})^ksecure^"`date +%y%m%d`".txt"
		
		{ # 시간, 호스트네임 등 기본 정보 저장(괄호로 묶어서 한번에 저장시키자)
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : Jeus(Unix)" 
		echo "Domain NAME : "$Domain 
		echo ""


		echo "=======================================================================" 
		# 서비스 버전정보등 출력
		echo "[ SW Info ]"
		${Install_Dir}/bin/jeusadmin -version
		echo ""

		echo "=======================================================================" 
		# 서버 IP 정보 출력
		# OS 별 IP 명령어가 다르므로 1차적으로 "ip addr" 하고, 에러나면 "netstat -in"으로 검색 
		echo "[ IP Info ]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 

		echo "=======================================================================" 
		echo "[ Process ]"
		ps -ef | grep jeus | grep -v grep
		echo ""

		echo "=======================================================================" 
		echo "[ Sample Directory ]" 
		# 샘플 디렉터리페이지 존재여부 확인
		ls -adl ${Install_Dir}/samples
		ls -adl ${Install_Dir}/docs/manuals
		ls -adl ${Domain_D}/servers/server1/.workspace/deployed/examples
		echo "" 


		echo "=======================================================================" 
		# 버전 확인
		echo "[ Version ]"
		${Install_Dir}/bin/jeusadmin -version

		echo ""
		echo "[ FullVersion ]"
		${Install_Dir}/bin/jeusadmin -fullversion
		echo ""


		echo "=======================================================================" 
		## 버전별로 필요한 설정파일이 달라서 나눔
		## 설치디렉터리에 존재하는 설정파일(진단에 필요한 것만) 목록 출력
		if [ "${conf6_D}" ]; then
			echo "[ JEUSMain.xml ]"
			echo ${JEUSMain_F};
			for file in ${JEUSMain_F}; do
				ls -l ${file}
				cat ${file}
				echo ""
			done
			echo ""
		
			echo "=======================================================================" 
			echo "[ accounts.xml ]"
			echo ${accounts6_F};
			for file in ${accounts6_F}; do
				ls -l ${file}
				cat ${file}
				echo ""
			done
			echo ""
		
		else
			echo "[ domain.xml ]"
			echo ${domain_F};
			cat ${domain_F};
			echo ""

			echo "=======================================================================" 
			echo "[ accounts.xml ]"
			echo ${accounts7_F};
			cat ${accounts7_F};
			echo ""
		fi


		echo "========================= complete!! =================================="
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1
	#JEUS End
	# 스크립트 종료 메시지 화면에 출력	
	echo "========================= complete!! =================================="

	elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
		## 질의문 총 2개(Install_Dir, Manager_URL)
		echo "(1/2) Input the Tomcat Install directory path."
		read Install_Dir
		
		## 입력받은 경로가 '/' 로 시작되는지 확인 (없을 경우 추가)
		if [ `echo $Install_Dir | grep -i "^/" | wc -l` -eq 0 ]; then
			Install_Dir="/${Install_Dir}"
		fi
		## 입력받은 Install_Dir에 conf 디렉터리가 존재해야 진짜 설치디렉터리이다.
		## find ${Install_Dir} -type d -name 'conf*'으로 하지 않은 이유는
		## 입력값이 설치디렉터리가 아닌 최상위 경로로 입력하면 무조건 참값으로 나오기때문
		conf_D=`ls -d ${Install_Dir}/conf 2>/dev/null`

		## 입력받은 Install_Dir에 server.xml 파일과 tomcat-users.xml 파일이 존재하는지 확인
		server_F=`find ${Install_Dir} /etc -type f -name 'server.xml' 2>/dev/null | grep '/etc/tomcat'`
		users_F=`find ${Install_Dir} /etc -type f -name 'tomcat-users.xml' 2>/dev/null | grep '/etc/tomcat'`
		web_F=`find ${Install_Dir} /etc -type f -name 'web.xml' 2>/dev/null | grep '/etc/tomcat'`
		context_F=`find ${Install_Dir} /etc -type f -name 'context.xml' 2>/dev/null | grep '/etc/tomcat'`
		webapps_context_F=`find ${Install_Dir}/webapps/*/META-INF /var/lib/*/webapps/*/META-INF -type f -name "context.xml" 2>/dev/null | grep '/var/lib/tomcat'`
		webapps_web_F=`find ${Install_Dir}/webapps/*/WEB-INF /var/lib/*/webapps/*/WEB-INF -type f -name "web.xml" 2>/dev/null | grep '/var/lib/tomcat'`
	

		## 아래 네개의 변수의 값이 하나라도 없으면 Install_Dir 경로가 잘못되거나, 설정파일이 존재하지 않는 경우
		## 설정파일이 존재하는 설치디렉터리 경로를 다시 입력 받아야 한다.

		if [ "${server_F}" -a "${users_F}" -a "${web_F}" -a "${context_F}" ]; then
			echo ""
		elif [ "${conf_D}" ]; then
			echo ""
		else
			echo "***********************************************************************"
			echo "The Answer is incorrect(Install Dir or CONF file does not exist). "
			echo "If you don't know, write down the command."
			echo "***********************************************************************"
			echo ""
			echo "ex) find / -type d -name '*tomcat*'"
			echo ""
			echo ""
			exit
		fi

		echo "(2/2) Input the Manager_URL.(Default:/manager)"
		read Manager_URL

		# 만약 입력값이 존재하지 않을 경우, /manager로 Manager_URL 치환
		# 입력값이 실제 사용 중인 Manager_URL 인지는 검증하지 않음
		if [ ! "${Manager_URL}" ]; then
			Manager_URL="/manager"
		fi

		## 저장파일 지정
		ResultFile_Name="Tomcat^"`hostname`"^ksecure^"`date +%y%m%d`".txt"

		{ # 시간, 호스트네임 등 기본 정보 저장(괄호로 묶어서 한번에 저장시키자)
		echo "=======================================================================" 
		echo "*** Info ***" 
		echo "=======================================================================" 
		echo "[Default Info]" 
		echo "DATE : "`date +%y-%m-%d` 
		echo "TIME : "`date +%H:%M:%S` 
		echo "HOST NAME : "`hostname` 
		echo "SW NAME : Tomcat(Unix)" 
		echo "Manager_URL : "${Manager_URL}
		echo ""

		echo "[SW Info]"
		${Install_Dir}/bin/version.sh
		echo ""

		# 서버 IP 정보 출력
		# OS 별 IP 명령어가 다르므로 1차적으로 "ip addr" 하고, 에러나면 "netstat -in"으로 검색 
		echo "[IP Info]" 
		if ip addr 2>/dev/null; then
			echo ""
		else
			netstat -in
		fi
		echo "" 

		echo "=======================================================================" 
		echo "*** Process ***" 
		echo "=======================================================================" 
		ps -ef | grep tomcat
		echo ""

		echo "=======================================================================" 
		echo "*** Config File Contents ***" 
		echo "======================================================================="
		# 설치디렉터리에 존재하는 server.xml, tomcat-users.xml, web.xml 내용 출력(여러개일 경우, 모두 출력)
		for file in ${server_F} ${users_F} ${web_F} ${context_F} ${webapps_web_F} ${webapps_context_F} ${log_F} ; do
			for filepath in ${file}; do
				echo "[ $filepath ]" 
				cat ${filepath}
				echo ""
			done
			echo "=======================================================================" 
			echo "" 
		done

		echo "========================= complete!! =================================="
		} > "${RESULTDIR}/${ResultFile_Name}" 2>&1	
		# 스크립트 종료 메시지 화면에 출력
		echo "========================= complete!! =================================="
		#Tomcat End
	fi
	

	echo " 3. Input start script running? (1) : "
	read FIND_CHECK
	echo ""
	
	if [ `echo $FIND_CHECK | egrep -i "1|2" | wc -l` -eq 0 ]; then
		while [ 1 ]
		do
			echo " 3. Input start script running? (1) : "
			read FIND_CHECK
			echo ""
			
			if [ `echo $FIND_CHECK | egrep -i "1|2" | wc -l` -gt 0 ]; then
				break
			fi
		done
	fi
	

	## 저장하는 결과 파일명 설정(RawData와 현황을 출력하는 xml파일과 total 결과값만 출력하는 txt, )
	XML_FILE_NAME="${RESULTDIR}/LINUX^"${HOSTNAME}"^ksecure^`date +%y%m%d`.xml"
	TOTAL_FILE_NAME="${RESULTDIR}/LINUX^"${HOSTNAME}"^ksecure^`date +%y%m%d`^RESULT.txt"
	AUDIT_FILE_NAME="${RESULTDIR}/LINUX^"${HOSTNAME}"^ksecure^`date +%y%m%d`^AUDIT.txt"
	> $TOTAL_FILE_NAME
	> $AUDIT_FILE_NAME
	
}


##### 전역변수 #####
if [ -f /etc/centos-release ]; then
	GS_OSVersion=`cat /etc/centos-release | awk -F"." '{print $1}' | awk '{print $NF}'`
else
	GS_OSVersion="7"
fi
GS_UserHomeDirectories=`cat /etc/passwd | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F":" '{print $6}'`
GS_ShadowConf="/etc/shadow"
#SRV_001, SRV_002
SNMPD_CONF="/etc/snmp/snmpd.conf /var/lib/net-snmp/snmpd.conf /usr/share/snmp/snmpd.conf /var/lib/snmp/snmpd.conf /var/net-snmp/snmpd.conf"
SNMPD_CONF_LIST="/etc/snmp/snmpd.conf /usr/share/snmp/snmpd.conf"
#SRV_005, SRV_006, SRV_007, SRV_009, SRV_010
SENDMAIL_CONF="/etc/mail/sendmail.cf"
GS_SendmailConf="/etc/mail/sendmail.cf /etc/sendmail.cf"
#SRV_011,13 SRV_161
GS_VsFTPUsersConf="/etc/vsftpd/ftpusers /etc/vsftpd.ftpusers"
GS_VsFTPConf="/etc/vsftpd/vsftpd.conf /etc/vsftpd.conf"
GS_VsFTPUserList="/etc/vsftpd/user_list /etc/vsftpd.user_list"
GS_ProFTPUsersConf="/etc/ftpusers /etc/ftpd/ftpusers /etc/proftpd/ftpusers"
GS_ProFTPConf="/etc/proftpd.conf /etc/proftpd/proftpd.conf" 
GS_FTPUsersConf="/etc/ftpusers /etc/ftpd/ftpusers"

FTPUSERS_CONF="/etc/ftpusers /etc/ftpd/ftpusers"
PROFTPUSERS_CONF="/etc/proftpd/ftpusers"
VSFTPUSERS_CONF="/etc/vsftpd/ftpusers /etc/vsftpd.ftpusers /etc/vsftpd/user_list /etc/vsftpd.user_list"
#SRV_013
VSFTPD_CONF="/etc/ftpd.conf /etc/vsftpd/vsftpd.conf /etc/vsftpd/conf"
PROFTPD_CONF="/usr/local/etc/proftpd.conf /usr/local/proftpd/etc/proftpd.conf /etc/proftpd.conf /etc/proftpd/proftpd.conf"
#SRV_016, SRV_019, SRV_030, SRV_035, #SRV_036, SRV_088, SRV_158
INETD_CONF="/etc/inetd.conf"
#SRV_016, SRV_019, SRV_030, SRV_035, #SRV_036, SRV_158
XINETD_DIR="/etc/xinetd.d"
#unix_035
#Unix_021
GS_FTPAccessConf="/etc/ftpaccess /etc/ftpd/ftpaccess"
GS_FTPHostsConf="/etc/ftphosts /etc/ftpd/ftphosts"
#SRV_088
XINETD_CONF="/etc/xinetd.conf"
#SRV_025
HOSTS_EQUIV="/etc/hosts.equiv"
#SRV_026
SECURETTY="/etc/securetty"
GS_SSHDConf="/etc/sshd_config /etc/ssh/sshd_config /usr/local/etc/sshd_config /usr/local/sshd/etc/sshd_config /usr/local/ssh/etc/sshd_config /etc/opt/ssh/sshd_config"
LOGIN_CONF="/etc/pam.d/login"
#SRV_027
GS_HostsAllow="/etc/hosts.allow"
#SRV_027
GS_HostsDeny="/etc/hosts.deny"
#Unix_035, Unix_315
GS_NISServices="ypserv ypbind ypxfrd rpc.yppasswdd rpc.ypupdated"
#SRV_036, SRV_099
SERVICES_CONF="/etc/services"
DOC_ROOT="/usr/local/apache/htdocs /usr/local/apache2/htdocs /var/www/html /var/www"
#SRV_062, SRV_063, SRV_066
GS_DNSConf="/etc/named.conf /etc/named.boot /etc/named.caching-nameserver.conf"
#SRV_073, SRV_131
GROUP_CONF="/etc/group"
#SRV_081

#SRV_082
SYSTEM_DIR="/bin /sbin /etc /var /usr/bin /usr/sbin"
#SRV_084, SRV_142, SRV_143, SRV_145, SRV_146, SRV_160
GS_PasswdConf="/etc/passwd"
#SRV_086
HOSTS_CONF="/etc/hosts"
#SRV_087
GCC_FILE="/usr/bin/gcc"
#SRV_089, SRV_168
SYSLOG_CONF="/etc/syslog.conf"
#SRV_089
RSYSLOG_CONF="/etc/rsyslog.conf"
#SRV_091
SUGID_STICKY_CHECK="/sbin/dump /usr/bin/lpq-lpd /usr/bin/newgrp /sbin/restore /usr/bin/lpr /usr/sbin/lpc /sbin/unix_chkpwd /usr/bin/lpr-lpd /usr/sbin/lpc-lpd /usr/bin/at /usr/bin/lprm /usr/sbin/traceroute /usr/bin/lpq /usr/bin/lprm-lpd"
#SRV_094
# CRONTAB_DIR="/etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly /usr/bin/crontab"
CRONTAB_DIR="/var/spool/cron/crontabs" 
#SRV_106
HOSTS_LPD="/etc/hosts.lpd"
CHECK_LOG_DIR="/var/log/"
CHECK_LOG_CONF="/etc/syslog.conf /etc/rsyslog.conf /etc/syslog-ng.conf  /etc/syslog-ng/syslog-ng.conf"
AT_FILE="/etc/at.allow /etc/at.deny"
LOGIN_LIMIT_CONF="/etc/pam.d/system-auth /etc/pam.d/password-auth"
LOGIN_LIMIT_MDL="pam_tally.so pam_tally2.so pam_faillock.so"

UMASK_CONF="/etc/profile /etc/bashrc /etc/csh.cshrc"
UMASK_USRCONF=".bashrc .bash_profile .tcshrc .cshrc .profile"
# Good_Ex="if[\$UID-gt199]&&[\"\`id-gn\`\"=\"\`id-un\`\"];then umask002 else umask022"
# Good_Ex2="if(\$uid>199&&\"\`id-gn\`\"==\"\`id-un\`\")then umask002 else umask022"
#SRV_108
CHECK_LOG_FILE="audit secure utmp syslog sulog pacct auth messages loginlog lastlog"
#SRV_121, SRV_130, SRV_159
GS_ProfileConf="/etc/profile /etc/.profile"
#SRV_131
SU_BIN=`which su`
#SRV_132, SRV_133
CRON_ALLOW="/etc/cron.allow"
CRON_DENY="/etc/cron.deny"
#SRV_159
GS_CshConf="/etc/csh.login /etc/.login"
#SRV_014
NFSD_CONF="/etc/exports"
#SRV_026
REMOTE_LOGIN_CONF="/etc/pam.d/login"
#SRV_074
PASSWD_POLICY_CONF="/etc/login.defs"
#SRV_107
AT_ALLOW="/etc/at.allow"
#SRV_107
AT_DENY="/etc/at.deny"
#계정잠금임계값
LOGIN_LIMIT_OPTIONS="lcredit ucredit dcredit ocredit minlen"
GS_ENVFiles=".profile .kshrc .cshrc .bashrc .bash_profile .login .exrc .netrc"
SYSSTART_IDR=`ls -adl /etc/rc.d/rc*.d/ | awk -F " " '{print $NF}'`
FIND_HOMEDIR_SORT=`cat /etc/passwd | egrep -v "^#|sbin/nologin|bin/false" | awk -F":" '{print $6}' | sort -u`
FIND_NOUSR_SORT=`cat /etc/passwd | awk -F"#" '{print $1}' | grep -v ":nosh\|sbin/nologin\|bin/false\|:/home\|:/root:\|:/:" | awk -F":" '{print $6}' | sort -u`" "`ls -dl /home/* | awk '{print $9}'`
FIND_HOMEDIR=`cat /etc/passwd | egrep -v "^#|sbin/nologin|bin/false"`
# APACHE_SAMPLE="manual manuals sample samples samples/* example/* examples/* docs/* test/* welcome/*"
SYSLOG_NG_CONF="/etc/syslog-ng/syslog-ng.conf"

XINETD_CONFGCK=0
INETD_CONFGCK=0
INETDON=1 # lo=0 inetd is disable and More than one process



#Xinetd 설정된 서비스 가져오기 (for PROCESS_CHECKER)
GA_Null=""
GS_XinetdConfingFile="/etc/xinetd.conf"
GS_TotalXinetdServices=""
GS_ActiveXinetdServices=""
LS_XinetdConfigDir=""

if [ -f /etc/xinetd.conf ]; then
	if [ `cat /etc/xinetd.conf | awk -F"#" '{print $1}' | grep -i "includedir" | wc -l` -gt 0 ]; then
	    LS_XinetdConfigDir=`cat /etc/xinetd.conf | awk -F"#" '{print $1}' | grep -i "includedir" | awk '{print $2}'`
	    LS_ServiceConfigFiles="${GS_XinetdConfingFile} "`ls ${LS_XinetdConfigDir} | awk '{print LS_XinetdConfigDir"/"$1}' LS_XinetdConfigDir=${LS_XinetdConfigDir}`
	else
	    LS_ServiceConfigFiles="${GS_XinetdConfingFile}"
	fi

	for LS_ServiceConfigFile in ${LS_ServiceConfigFiles}; do
	        cat ${LS_ServiceConfigFile} | awk -F"#" {'print $1'} >> ksecure/xinetdMerge
	done

	sed -i '/^$/d' ksecure/xinetdMerge

	LB_DisableExist=0
	LB_ServiceSyntaxStart=0

	while read line
	do
	    if [ `echo ${line} | awk -F"#" '{print $1}' |grep "service" | wc -l` -gt 0 ]; then
	    # xinetd 설정 파일의 서비스 구문 시작
	        LB_ServiceSyntaxStart=1
	        LS_CurrentServices=`echo ${line} | awk -F" " '{print $2}'`
	        GS_TotalXinetdServices="${GS_TotalXinetdServices}${LS_CurrentServices} "
	    fi

	    # 서비스 구문 시작되면 disable 속성이 있는지, 설정 값이 no로 되어 있는지 확인해서 실행되는 서비스를 찾아서 변수 추가
	    if [ $LB_ServiceSyntaxStart -eq 1 ]; then
	        if [ `echo ${line} | grep "disable" | wc -l` -gt 0 ]; then
	                LB_DisableExist=1
	            if [ `echo ${line} | awk -F"=" '{print $2}' | grep "no" | wc -l` -gt 0 ]; then
	                GS_ActiveXinetdServices="${GS_ActiveXinetdServices}${LS_CurrentServices} "
	        	elif [ `echo ${line} | awk -F"=" '{print $2}' | wc -w` -eq 0 ]; then
	                GS_ActiveXinetdServices="${GS_ActiveXinetdServices}${LS_CurrentServices} "
	            fi
	        fi
	        if [ `echo ${line} | grep "}" | wc -l` -gt 0 ]; then
	             LB_ServiceSyntaxStart=0
	             if [ ${LB_DisableExist} -eq 0 ]; then
	                GS_ActiveXinetdServices="${GS_ActiveXinetdServices}${LS_CurrentServices} "
	             fi
	             LB_DisableExist=0
	        fi
	    fi
	done < ksecure/xinetdMerge
fi

# 프로세스 체커
PROCESS_CHECKER(){

	PCK=0
	PROCESS_NAME=$1
	SYSTEMD_PROCESS_NAME=$2
	
	if [ `echo ${SYSTEMD_PROCESS_NAME} | wc -w` -gt 0 ]; then
		if [ `systemctl "is-active" ${SYSTEMD_PROCESS_NAME} | wc -w` -gt 0 ]; then
			echo "[ ${SYSTEMD_PROCESS_NAME} ]"
			systemctl "is-active" ${SYSTEMD_PROCESS_NAME}
			echo ""
			if [ `systemctl "is-active" ${SYSTEMD_PROCESS_NAME} | grep -v "inactive" | grep "active" | wc -w` -gt 0 ]; then
				PCK=1
			fi
		fi
	fi
	  

	if [ `ps -ef | grep -v 'grep' | grep -i $PROCESS_NAME | wc -l` -gt 0 ]; then
		echo "[ $PROCESS_NAME ]"
		ps -ef | grep -v grep | grep -i $PROCESS_NAME
		PCK=1
		echo " "
	fi

	if [ `ps -ef | grep -i inetd | grep -vi xinetd | grep -v 'grep' | wc -l` -gt 0 ]; then	
		if [ $INETDON -gt 0 ]; then
			if [ -f /etc/inetd.conf ]; then
				INETD_CONFGCK=1 # INETD_CONFGCK=1 INETD_CONFG exist and INETD active
				if [ `cat /etc/inetd.conf | grep $PROCESS_NAME | grep -v '^#' | wc -l` -gt 0 ]; then
					echo "[ $PROCESS_NAME inetd check ]"
					cat /etc/inetd.conf | grep $PROCESS_NAME | grep -v '^#'
					PCK=1
					echo " "
				fi
			else
				INETD_CONFGCK=2 # INETD_CONFGCK=2 INETD_CONFG NOT FOUND and INETD active
				echo "INETD_CONF NOT FOUND!"
			fi
		fi
	fi

	if [ `ps -ef | grep -i xinetd |grep -v 'grep' | wc -l` -gt 0 ]; then
	 	if [ -f ${GS_XinetdConfingFile} ]; then
	 	 	XINETD_CONFGCK=1
	 	 	if [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "disabled" | grep "${PROCESS_NAME}" | wc -l` -gt 0 ]; then
	        	GA_NULL="0"
			#   echo "disabled 설정에 체크할 서비스가 존재해서 실행되지 않음"
			elif [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "enabled" | grep "${PROCESS_NAME}" | wc -l` -gt 0 ]; then
			    if [ `echo ${GS_TotalXinetdServices} | grep -i "${PROCESS_NAME}" | wc -l` -gt 0 ]; then
			#   	echo "enabled에 체크할 서비스가 존재하고 상세 설정도 존재함"
			    	PCK=1
			    	echo "[ $PROCESS_NAME ]"
				    echo "${PROCESS_NAME} service running with xinetd"
				    echo ""
			#   else
			#   	echo "enabled에 체크할 프로세스가 존재하지만 상세 설정이 존재하지 않음"
			    fi
			elif [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "enabled" | awk -F"=" '{print $2}' | wc -l` -gt 0 ]; then
			    GA_Null="0"
			#   echo "enabled은 활성화되어 있지만 체크할 프로세스가 존재하지 않음"
			elif [ `echo "${GS_ActiveXinetdServices}" | grep -i "${PROCESS_NAME}" | wc -l` -gt 0 ]; then
			#   echo "활성화된 서비스 중 체크할 프로세스가 존재함"
			    PCK=1
			    echo "[ $PROCESS_NAME ]"
			    echo "${PROCESS_NAME} service running with xinetd"
			    echo ""
			#else
			#   echo "프로세스 실행 안함"
			fi
	 	else
	 	 	echo "XINETD_CONF NOT FOUND!"
	 	 	XINETD_CONFGCK=2
	 	fi
	fi
	 
	if [ `rpcinfo -p | grep $PROCESS_NAME | wc -l` -gt 0 ]; then
		echo "[$PROCESS_NAME rpcinfo -p command check]"
		rpcinfo -p | grep $PROCESS_NAME
		PCK=1
	    echo " "
	fi

	PROCESS_NAME=""
} 


LINK_DIR_CK(){
	DIRCK=$1
	DIRCKNUM=0
	DIRREAL=""
	if [ `ls -adl $1 | grep "^l........." | wc -l` -eq 1 ]; then
		DIRCKNUM=1
		DIRREAL=`ls -adl $1 | awk -F " " '{print $NF}'`
	fi
}

RAW_PRINT(){
	LS_CONFIG="/etc/hosts.equiv /etc/rc.d/rc*.d/* /var/spool/cron/* /var/spool/cron/crontabs/* /etc/at.allow /etc/at.deny /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.allow /etc/cron.deny /etc/passwd /etc/hosts /etc/rsyslog.conf /etc/syslog.conf /etc/services /etc/hosts.lpd /etc/shadow /etc/xinetd.conf /etc/inetd.conf /usr/bin/gcc /sbin/dump /usr/bin/lpq_lpd /usr/bin/newgrp /usr/bin/lpr /usr/sbin/lpc /sbin/unix_chkpwd /usr/bin/at /usr/bin/lprm /usr/sbin/traceroute /usr/bin/lpq /usr/bin/lprm_lpd /usr/bin/lpr_lpd /usr/sbin/lpc_lpd /sbin/restore /var/log/audit /var/log/secure /var/log/wtmp /var/log/utmp /var/log/btmp /var/log/syslog /var/log/sulog /var/log/pacct /var/log/auth /var/log/messages /var/log/loginlog /var/log/lastlog /usr/bin/su /bin/su /etc/ftpusers /etc/ftpd/ftpusers /etc/proftpd/ftpusers /etc/vsftpd/user_list /etc/vsftpd/ftpusers /etc/vsftpd.ftpusers /etc/vsftpd.user_list /etc/exports /etc/exim4/conf.d"
	CHECKFILE=".profile .kshrc .cshrc .bashrc .bash_profile .login .exrc .netrc .rhosts"
	
	LS_DIR="/usr /bin /sbin /etc /var /etc/rc.d/rc*.d /dev /usr/local/server/tomcat/webapps/manager /usr/local/server/tomcat/webapps/admin"
	
	whichfile="gcc su"
	CAT_FILE="/etc/snmpd.conf /etc/snmp/conf/snmpd.conf /etc/snmp/snmpd.conf /usr/share/snmp/snmpd.conf /etc/snmpdv3.conf /etc/sma/snmp/snmpd.conf /etc/inetd.conf /etc/xinetd.d/* /etc/mail/sendmail.cf /etc/postfix/main.cf /var/qmail/service/smtpd /etc/postfix/master.cf /etc/exim/exim.conf /etc/exim/exim4.conf /etc/exim4/exim4.conf.template /etc/exim4/conf.d/*.conf /etc/mail/access /etc/ftpusers /etc/ftpd/ftpusers /etc/proftpd/ftpusers /etc/proftpd.conf /etc/vsftpd/ftpusers /etc/vsftpd.ftpusers /etc/vsftpd/vsftpd.conf /etc/vsftpd.conf /etc/vsftpd/user_list /etc/vsftpd.user_list /etc/passwd /etc/shells /usr/local/proftpd/etc/proftpd.conf /etc/exports /etc/inittab /etc/xinetd.d/rpc.cmsd /etc/xinetd.d/rusersd /etc/xinetd.d/rstatd /etc/xinetd.d/rpc.ttdbserverd /etc/xinetd.d/kcms_server /etc/xinetd.d/Walld /etc/xinetd.d/rpc.nids /etc/xinetd.d/rpc.ypupdated /etc/xinetd.d/cachefsd /etc/xinetd.d/sadmind /etc/xinetd.d/sprayd /etc/xinetd.d/rpc.pcnfsd /etc/xinetd.d/rexd /etc/xinetd.d/rpc.rquotad /etc/shadow /etc/hosts.equiv /etc/ssh/sshd_config /etc/securetty /etc/pam.d/remote /etc/local/etc/sshd_config /usr/local/sshd/etc/sshd_config /usr/local/ssh/etc/sshd_config /etc/opt/ssh/sshd_config /etc/pam.d/login /etc/sshd_config /etc/hosts.deny /etc/hosts.allow /etc/rc.d/init.d/iptables /etc/ipf/ipf.conf /etc/profile /etc/csh.login /etc/.login /etc/.profile /etc/csh.cshrc /etc/xinetd.d/tftp /etc/xinetd.d/talk /etc/xinetd.d/ntalk /etc/xinetd.d/finger /etc/xinetd.d/rexec /etc/xinetd.d/rlogin /etc/xinetd.d/rsh /etc/xinetd.d/rsync /etc/xinetd.d/echo /etc/xinetd.d/discard /etc/xinetd.d/daytime /etc/xinetd.d/chargen /etc/xinetd.d/ftp /etc/xinetd.d/vsftp /etc/xinetd.d/proftp /etc/httpd/conf/httpd.conf /usr/local/server/tomcat/conf/tomcat_users.xml /etc/named.conf /etc/named.boot /etc/security/pwquality.conf /etc/pam.d/common-password /etc/pam.d/system-auth /etc/pam.d/password-auth /etc/pam.d/common-auth /etc/pam.d/common-account /etc/login.defs /etc/group /var/spool/cron/* /etc/syslog.conf /etc/rsyslog.conf /etc/rsyslog.d/* /etc/*-release /etc/pam.d/su /etc/cron.allow /etc/cron.deny /etc/xinetd.d/telnet /etc/issue.net /etc/motd /etc/issue /etc/security/login.cfg /etc/ftpaccess /.profile /usr/local/proftpd/lib/pkgconfig/proftpd.pc /etc/security/faillock.conf"

	echo "=======================================================================" 
	echo "*** uname -a ***" 
	echo "=======================================================================" 
	uname -a
	echo ""

	echo "=======================================================================" 
	echo "*** ifconfig -a ***" 
	echo "=======================================================================" 
	ifconfig -a
	echo ""

	echo "=======================================================================" 
	echo "*** ps -ef ***" 
	echo "=======================================================================" 
	ps -ef
	echo ""
	
	if [ -f /etc/xinetd.conf ]; then
		echo "=======================================================================" 
		echo "*** /etc/xinetd.conf ***" 
		echo "=======================================================================" 
		cat /etc/xinetd.conf
		echo ""

		if [ -d ${LS_XinetdConfigDir} ]; then
			echo "=======================================================================" 
			echo "*** /etc/xinetd.d ***" 
			echo "=======================================================================" 
			ls -al "${LS_XinetdConfigDir}"
			echo ""
		fi

		for LS_ServiceConfigFile in ${LS_ServiceConfigFiles}; do
			echo "=======================================================================" 
			echo "*** cat ${LS_ServiceConfigFile} ***" 
			echo "=======================================================================" 

			if [ -f ${LS_ServiceConfigFile} ]; then
				cat ${LS_ServiceConfigFile}
			else
				echo "$CONFIG NOT FOUND"
			fi
			echo ""
		done

	fi

	
	echo "=======================================================================" 
	echo "*** /etc/inetd.conf ***" 
	echo "=======================================================================" 
	if [ -f /etc/inetd.conf ]; then
		cat /etc/inetd.conf
	else
		echo "INETD SERVICE DISABLED"
	fi
	echo ""

	echo "=======================================================================" 
	echo "*** systemctl list-units ***" 
	echo "=======================================================================" 
	if [ `systemctl list-units | wc -w` -gt 0 ]; then
		systemctl list-units
	fi
	echo ""
	
	for CONFIG in ${LS_CONFIG}; do
		echo "=======================================================================" 
		echo "*** ls -alL $CONFIG ***" 
		echo "=======================================================================" 
		if [ -f $CONFIG ]; then
			ls -alL $CONFIG
		else
			echo "$CONFIG NOT FOUND"
		fi 
		echo ""
	done
	echo ""
	
	for HOMEDIR in ${FIND_HOMEDIR_SORT}; do
		FILECNT=0
		for FILE in ${GS_ENVFiles}; do
			if [ -f ${HOMEDIR}/${FILE} ]; then
				FILECNT=1
				echo "=======================================================================" 
				echo "*** ls -alL ${HOMEDIR} ENV_FILE ***" 
				echo "=======================================================================" 
				ls -alL ${HOMEDIR}/${FILE}
			
			fi
			
		done
		if [ ${FILECNT} -eq 0 ]; then
			echo "=======================================================================" 
			echo "*** ls -alL ${HOMEDIR} ENV_FILE ***" 
			echo "=======================================================================" 
			echo "${HOMEDIR} ENV_FILE NOT FOUND"
		fi
		echo ""
	done

	for wf in ${whichfile}; do
		swhich=`which $wf 2>/dev/null`
		echo "=======================================================================" 
		echo "*** ls -alL $swhich ***" 
		echo "=======================================================================" 
		if [ -f $swhich ]; then
			ls -alL $swhich
		else
			echo "$swhich NOT FOUND"
		fi
		echo ""
	done


	for DIRS in ${LS_DIR}; do
		echo "=======================================================================" 
		echo "*** ls -adL $DIRS ***" 
		echo "=======================================================================" 
		if [ -d $DIRS ]; then
			ls -adl $DIRS
		else
			echo "$DIRS NOT FOUND"
		fi
		echo ""
	done


	for AS in ${APACHE_SAMPLE}; do
		echo "=======================================================================" 
		echo "*** ls -adL $AS ***" 
		echo "=======================================================================" 
		if [ -d $AS ]; then
			ls -adl $AS
		else
			echo "$AS NOT FOUND"
		fi
		echo ""
	done


	for HOME in ${FIND_HOMEDIR_SORT}; do
		echo "=======================================================================" 
		echo "*** ls -adL $HOME ***" 
		echo "=======================================================================" 
		if [ -d $HOME ]; then
			ls -adl $HOME
		else
			echo "${HOME} NOT FOUND"
		fi
		echo ""
	done



	for SYSDIR in ${SYSSTART_IDR}; do
		echo "=======================================================================" 
		echo "*** ls -adL $SYSDIR ***" 
		echo "=======================================================================" 
		if [ -d ${SYSDIR} ]; then 
				ls -adl $SYSDIR
		else
			echo "${SYSDIR} NOT FOUND"
		fi 
		echo ""
	done

	if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then	
		DEVFILENAME=`find /dev -type f -exec ls -l {} \; | grep -v '/dev/nul' | grep -v '/dev/rmt0' | awk -F" " '{print $9}'`
		echo "=======================================================================" 
		echo "*** find /dev files ***" 
		echo "=======================================================================" 
		if [ `echo ${DEVFILENAME} | wc -w` -gt 0 ]; then 
			for DEVFILE in ${DEVFILENAME}; do
				if [ -f $DEVFILE ]; then
					ls -alL $DEVFILE
				else
					echo "$DEVFILE NOT FOUND"
				fi
				echo ""
			done
		else	
			echo "Device file does not exist after checking file for dev"
			echo ""
		fi
	fi
		
	locate_xterm=`find /usr /bin -perm -1 -type f -name xterm`
	echo "=======================================================================" 
	echo "*** find xterm ***" 
	echo "=======================================================================" 
	if [ `echo ${locate_xterm} | wc -w` -gt 0 ]; then 
		for xterm in ${locate_xterm}; do
			if [ -f $xterm ]; then
				ls -alL $xterm
			else
				echo "$xterm NOT FOUND"
			fi
			echo ""
		done
	else
		echo "${xterm} NOT FOUND"
		echo ""
	fi

	FILECNT=0
	if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then
		echo "=======================================================================" 
		echo "*** find world writable file ***" 
		echo "=======================================================================" 
		for HOME in ${FIND_HOMEDIR_SORT}; do
			if [ $HOME != "/" -a $HOME != "/root" -a -d $HOME ]; then
				badfiles=`find $HOME -perm -2 -type f -exec ls -alL {} \; 2>/dev/null` 
				if [ `echo $badfiles | wc -w` -gt 0 ]; then
					FILECNT=1
					echo "* $HOME world writable file"
					echo "$badfiles"
					echo ""
				fi
			fi
		done
		if [ ${FILECNT} -eq 0 ]; then
			echo "world writable file NOT FOUND"
			echo ""
		fi
	fi
	
	FILECNT=0
	echo "=======================================================================" 
	echo "*** find nouser nogroup file/folder ***" 
	echo "=======================================================================" 
	for HOME in ${FIND_NOUSR_SORT}; do
		badfiles=`find ${HOME} \( -type d -o -type f \) -a \( -nouser -o -nogroup \) -xdev 2>/dev/null`
		
		if [ `echo $badfiles | wc -w` -gt 0 ]; then
			FILECNT=1
			echo "* $HOME nouser nogroup file"
			echo "$badfiles"
			echo ""
		fi
	done
	if [ ${FILECNT} -eq 0 ]; then
		echo "nouser nogroup file/dir NOT FOUND"
		echo ""
	fi


	FILECNT=0
	if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then
		echo "=======================================================================" 
		echo "*** find hidden file/folder ***" 
		echo "=======================================================================" 
		for HOME in ${FIND_HOMEDIR_SORT}; do
			if [ $HOME != "/" -a $HOME != "/root" -a -d $HOME ]; then
				
				badfiles=`find $HOME -type f -name ".*" -exec ls -l {} \; 2>/dev/null` 
				if [ `echo $badfiles | wc -w` -gt 0 ]; then
					FILECNT=1
					echo "* $HOME hidden file"
					echo "$badfiles"
					echo ""
				fi
			
				baddirs=`find $HOME -type d -name ".*" -exec ls -l {} \; 2>/dev/null` 
				if [ `echo $baddirs | wc -w` -gt 0 ]; then
					FILECNT=1
					echo "* $HOME hidden dir"
					echo "$baddirs"
					echo ""
				fi
			fi
		
		done
		if [ ${FILECNT} -eq 0 ]; then
			echo "hidden file/folder NOT FOUND"
			echo ""
		fi
	fi
		
	for CF in ${CAT_FILE}; do
		echo "=======================================================================" 
		echo "*** cat $CF ***" 
		echo "=======================================================================" 
		if [ -f $CF ]; then
			cat $CF
		else
			echo "$CF NOT FOUND"
		fi
		echo ""
	done
	

	echo "=======================================================================" 
	echo "*** proftpd include file ***" 
	echo "=======================================================================" 

	for LS_File1 in ${GS_ProFTPConf}; do
        if [ -f ${LS_File1} ]; then
			LS_IncludeFiles=`cat "${LS_File1}" | grep "Include" | awk '{print $2}'`
			for LS_IncludeFile in ${LS_IncludeFiles}; do
				if [ -f ${LS_IncludeFile} ]; then
					echo "[ ${LS_IncludeFile} ]"
					cat ${LS_IncludeFile}
					echo ""
				fi
			done
		fi
	done

	echo "=======================================================================" 
	echo "*** cat /var/spool/cron/crontabs/* ***" 
	echo "=======================================================================" 
	if [ -d ${CRONTAB_DIR} ];then
		if [ `cat /var/spool/cron/crontabs/* | wc -l` -gt 0 ]; then
			cat /var/spool/cron/crontabs/*
			ls -al /var/spool/cron/crontabs/*
		else
			echo "/var/spool/cron/crontabs/* NOT FOUND"
		fi
	else
		if [ `cat /var/spool/cron/* 2>/dev/null | wc -l` -gt 0 ]; then
			cat /var/spool/cron/*
			ls -al /var/spool/cron/*
		else
			echo "/var/spool/cron/* NOT FOUND"
		fi
	fi
	
	echo ""
	echo "=======================================================================" 
	echo "*** cat /etc/pam.d/passwd ***" 
	echo "=======================================================================" 
	if [ -f /etc/pam.d/passwd ] ; then
		cat /etc/pam.d/passwd
	else
			echo "/etc/pam.d/passwd NOT FOUND"
		fi
	echo ""
	
	echo "=======================================================================" 
	echo "*** cat /etc/security/pwquality.conf ***" 
	echo "=======================================================================" 
	if [ -f /etc/security/pwquality.conf ] ; then
		cat /etc/security/pwquality.conf
	else
			echo "/etc/security/pwquality.conf NOT FOUND"
		fi
	echo ""

	echo "=======================================================================" 
	echo "*** PROCESS_CHECKER Web Service ***" 
	echo "=======================================================================" 
	
	pck_WebServices="httpd wsm jeus"
	for web_Service in ${pck_WebServices}; do
         PROCESS_CHECKER ${web_Service}

         if [ ${PCK} -eq 0 ]; then
            echo "[ ${web_Service} ]"
            echo "${web_Service} SERVICE NOT ACTIVATE"
            echo ""
         fi
     done
	
	PROCESS_CHECKER syslog
	LS_Result=`PROCESS_CHECKER syslog`
	if [ "${PCK}" -gt 0 ]; then
		if [ `echo "${LS_Result}" | grep "rsyslog" | wc -l` -gt 0 ]; then
			if [ -f "/etc/rsyslog.conf" ]; then
				#8.33 이상 버전에서 include 확인
				if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 1p` -ge 8 ]; then
					if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 2p` -ge 33 ]; then
						if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | wc -l` -gt 0 ]; then
							file_name=`cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | grep -oP 'file="\K[^"]+'`
							file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
							#include 존재할 경우 출력
							echo "=======================================================================" 
							echo "*** ls -al ${file_name} ***" 
							echo "=======================================================================" 
							#파일이 존재할 경우
							if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' |wc -l` -gt 0 ]; then
								ls -al ${file_name}
								echo ""
								for file in ${file_list}; do
									echo ""
									echo "=======================================================================" 
									echo "*** cat $file ***"
									echo "=======================================================================" 
									cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
								done
							else
								echo "${file_name} NOT FOUND"
								echo ""
							fi
						fi
					fi
				fi
				
				#includeconfig 확인
				if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -i '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
					file_name=`cat /etc/rsyslog.conf | awk -F '#' '{print $1}' | grep -i '^\s*\$IncludeConfig' | awk '{print $2}'`
					file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
					#includeconfig 존재할 경우 출력
					echo "=======================================================================" 
					echo "*** ls -al ${file_name} ***" 
					echo "=======================================================================" 
					#파일이 존재할 경우
					if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' | wc -l` -gt 0 ]; then
						ls -al ${file_name}
						echo ""
						for file in ${file_list}; do
							echo ""
							echo "=======================================================================" 
							echo "*** cat $file ***"
							echo "=======================================================================" 
							cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
						done
					else
						echo "${file_name} NOT FOUND"
						echo ""
					fi
				fi
			fi
		fi
	fi
	
	echo ""
	echo "========================= complete!! =================================="
	
} > ${RESULTDIR}/RAWDATA_OUTPUT.txt

SNMP_RAW_PRINT(){
	echo ""
} > ${RESULTDIR}/SNMP_RAWDATA_OUTPUT.txt


계정잠금임계값_RAWDATA(){

	version=$(
		(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null || \
		grep -oP '\d+(?=\.)' /etc/os-release 2>/dev/null) || \
		grep -oP '\d+' /etc/redhat-release 2>/dev/null | head -n 1 || \
		awk '{print $NF}' /etc/redhat-release 2>/dev/null | awk -F"." '{print $1}'
	)


	echo "-------------------------------------------------------------------"
	#(공통)permitemptypassowrds 확인
	for FILE in ${GS_SSHDConf}; do
	if [ -f ${FILE} ]; then
		LI_FileExist=1
		echo ""
		echo "[ sshd config (${FILE}) ]"
		cat /etc/ssh/sshd_config
		echo ""
	fi
	done

	if [ "${LI_FileExist}" -eq 0 ]; then
		LB_CheckCase1=1
		echo "sshd config NOT FOUND"
		echo ""
	fi
	echo "-------------------------------------------------------------------"
	# ubuntu 20버전 이상 사용
	if [ $version -ge 20 ]; then
		echo "[ /etc/pam.d/common-auth ]"
		if [ -f "/etc/pam.d/common-auth" ]; then
			cat /etc/pam.d/common-auth
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		echo "[ /etc/security/faillock.conf ]"
		if [ -f "/etc/security/faillock.conf" ]; then
				cat "/etc/security/faillock.conf"
				echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		echo "[ /etc/pam.d/common-account ]"
		if [ -f "/etc/pam.d/common-account" ]; then
			cat "/etc/pam.d/common-account"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
	#Redhat 8버전 이상 사용
	elif [ $version -ge 8 ]; then
		# with-faillock 활성화 확인
		echo "[ authselect current ]"
		echo `authselect current`
		echo ""
		echo "-------------------------------------------------------------------"
		echo "[ /etc/security/faillock.conf ]"
		if [ -f "/etc/security/faillock.conf" ]; then
			cat "/etc/security/faillock.conf"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		echo "[ /etc/pam.d/system-auth ]"
		if [ -f "/etc/pam.d/system-auth" ]; then
			cat "/etc/pam.d/system-auth"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
			LB_CheckCase1=1
		fi
		echo "-------------------------------------------------------------------"
		echo "[ /etc/pam.d/password-auth ]"
		if [ -f "/etc/pam.d/password-auth" ]; then
			cat "/etc/pam.d/password-auth"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		
	#Redhat 6,7 버전 사용
	elif [ $version -ge 6 ]; then
		echo "[ /etc/pam.d/system-auth ]"
		if [ -f "/etc/pam.d/system-auth" ]; then
			cat "/etc/pam.d/system-auth"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		echo "[ /etc/pam.d/password-auth ]"
		if [ -f "/etc/pam.d/password-auth" ]; then
			cat "/etc/pam.d/password-auth"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
	#Redhat 5버전 사용
	elif [ $version -ge 5 ]; then
		echo "[ /etc/pam.d/system-auth ]"
		if [ -f "/etc/pam.d/system-auth" ]; then
			cat "/etc/pam.d/system-auth"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
		fi
	elif [ $version -le 4 ]; then
		echo "OS information Check"
	fi
} > ${RESULTDIR}/계정잠금임계값_RAWDATA.txt

XML_HEADER() {
	{
		echo "<?xml version='1.0' encoding='${ENCODING}'?>"
		echo " "
		echo "<root>"
		echo "<SYSTEM_INFO>"
		echo "<SW_TYPE>SERVER</SW_TYPE>"
		echo "<SW_NM>Linux</SW_NM>"
		echo "<SW_INFO>${SW_INFO}</SW_INFO>"
		echo "<HOST_NM>${HOSTNAME}</HOST_NM>"
		echo "<ASSET>주요정보통신기반시설 2026 가이드</ASSET>"
		echo "<SCRIPT>K-Secure</SCRIPT>"
		echo "<DATE>`date +'%g-%m-%d'`</DATE>"
		echo "<TIME>`date +'%T'`</TIME>"
		echo "<IP_ADDRESS>${IPADDR_LIST}</IP_ADDRESS>"
		
		#for IP in ${IPADDR_LIST}; do
		#	echo ${IP}
		#done
		#echo "</IP_ADDRESS>"
		
		echo "</SYSTEM_INFO>"
		echo "<DIAGNOSIS_LIST>"
	} > $XML_FILE_NAME
}

XML_BODY() {
	{
		echo ""
		echo "<DIAGNOSIS>"
		echo "<CODE>${CODE}</CODE>"
		echo "<ITEM_GROUP_NAME>${ITEM_GROUP_NAME}</ITEM_GROUP_NAME>"
		echo "<ITEM_NAME>${ITEM_NAME}</ITEM_NAME>"
		echo "<ITEM_GRADE>${ITEM_GRADE}</ITEM_GRADE>"
		
		echo "<STANDARD>"
		echo "<![CDATA["
		cat $STANDARD_FILE
		echo "]]>"
		echo "</STANDARD>"
		
		echo "<STATUS>"
		echo "<![CDATA["
		cat $STATUS_FILE
		echo "]]>"
		echo "</STATUS>"

		echo "<RESULT>${RESULT}</RESULT>"
		echo "</DIAGNOSIS>"
	} >> $XML_FILE_NAME
	TOTAL_RESULT
}

XML_BODY_NA() {
	{
		echo ""
		echo "<DIAGNOSIS>"
		echo "<CODE>${CODE}</CODE>"
		echo "<ITEM_GROUP_NAME>${ITEM_GROUP_NAME}</ITEM_GROUP_NAME>"
		echo "<ITEM_NAME>${ITEM_NAME}</ITEM_NAME>"
		echo "<ITEM_GRADE>${ITEM_GRADE}</ITEM_GRADE>"

		echo "<STANDARD>
		<![CDATA["
		echo "N/A"
		echo "]]>
		</STANDARD>"

		echo "<STATUS>
		<![CDATA["
		echo "N/A"
		echo "]]>
		</STATUS>"

		echo "<RESULT>N/A</RESULT>"
		echo "</DIAGNOSIS>"
	} >> $XML_FILE_NAME
	RESULT="N/A"
	TOTAL_RESULT
}

XML_FOOTER() {
	{
		echo "</DIAGNOSIS_LIST>"
		echo "</root>"
	} >> $XML_FILE_NAME 2> /dev/null
}

TOTAL_RESULT() {
	{
		echo "${CODE} ${RESULT}"
	} >> $TOTAL_FILE_NAME
}

## VBA 파싱용 ★/▶ 형식 출력
AUDIT_RESULT() {
	{
		echo "▶ [${ITEM_GROUP_NAME}] ${ITEM_NAME} [${ITEM_GRADE}]"
		cat $STATUS_FILE | grep -v "^---"
		case "${RESULT}" in
			"GOOD") echo "★ ${CODE} 결과: 양호" ;;
			"BAD")  echo "★ ${CODE} 결과: 취약" ;;
			"CHECK") echo "★ ${CODE} 결과: 수동점검" ;;
			*)      echo "★ ${CODE} 결과: ${RESULT}" ;;
		esac
	} >> $AUDIT_FILE_NAME
}

CHECK(){
	CODE=$2
	ITEM_GROUP_NAME=$3
	ITEM_NAME=$4
	ITEM_GRADE=$5

	$1
	XML_BODY
	AUDIT_RESULT
	printf "$CODE. Completed ...\t\t\n"
}

CHECK_NA(){
	CODE=$2
	ITEM_GROUP_NAME=$3
	ITEM_NAME=$4
	ITEM_GRADE=$5

	XML_BODY_NA
	{
		echo "▶ [${ITEM_GROUP_NAME}] ${ITEM_NAME} [${ITEM_GRADE}]"
		echo "N/A"
		echo "★ ${CODE} 결과: N/A"
	} >> $AUDIT_FILE_NAME
	printf "$CODE. Completed ...\t\t\n"
}


Unix_001(){
	{
		echo "양호: 보안설정이 적용된 네트워크 모니터링 서비스를 사용하는 경우"
		echo "취약: 보안설정이 적용되지 않은 네트워크 모니터링 서비스를 사용하는 경우"
	}  > $STANDARD_FILE

	{
		LB_BadCase=0
		LB_GoodCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LI_FileExist=0
		CNT=0
		CASE=0
		FLAG=0
		echo "-------------------------------------------------------------------"

		if [ "${PCK}" -gt 0 ]; then # SNMP 서비스가 활성화 되어 있을 경우
			echo "[ SNMPD Version ]"
			snmpd -v | sed '/^$/d'
			echo ""		
			PROCESS_CHECKER snmpd
			
			if [ $(snmpd -v | awk '/NET-SNMP version/{print $3}') \< 4.0.0 ]; then # NET-SNMP 버전이 4 미만일 경우 취약으로 판단
				LB_BadCase=1			
			elif [ -f /etc/snmp/snmpd.conf ]; then # /etc/snmp/snmpd.conf 파일 존재 확인
				LB_CheckCase4=1
				if [ `cat /etc/snmp/snmpd.conf | grep -v '^#' | grep -ie 'v1' -ie 'v2c' -ie 'rocommunity' -ie 'rwcommunity' -ie 'com2sec' | wc -l` -gt 0 ]; then
					echo "[ /etc/snmp/snmpd.conf SNMP v1, v2 사용자 설정 확인 ]"
					echo "SNMP_RAW_DATA.txt 확인"
					echo ""			
				else
					echo "[ /etc/snmp/snmpd.conf SNMP v1,v2 확인 불가 ]"
					echo "SNMP_RAW_DATA.txt 확인"
					echo ""	
				fi
				if [ `cat /etc/snmp/snmpd.conf | grep -v '^#' | grep -ie 'v3' -ie 'rouser' -ie 'rwuser' | wc -l` -gt 0 ]; then	
					echo "[ /etc/snmp/snmpd.conf SNMP v3 사용자 설정 확인 ]"
					echo "SNMP_RAW_DATA.txt 확인"
					echo ""	
				else
					echo "[ /etc/snmp/snmpd.conf SNMP v3 확인 불가 ]"
					echo "SNMP_RAW_DATA.txt 확인"
					echo ""	
					if [ `cat /etc/*-release | grep -i ubuntu | wc -l` -gt 0 ]; then # Ubuntu일 경우
						if [ -f /usr/share/snmp/snmpd.conf ]; then # /usr/share/snmp/snmpd.conf 파일 존재		
							echo "[ /usr/share/snmp/snmpd.conf v3 사용자 확인 ]"
							echo "SNMP_RAW_DATA.txt 확인"
							echo ""		
						else
							echo "[ /usr/share/snmp/snmpd.conf v3 사용자 확인 불가 ]"
							echo "SNMP_RAW_DATA.txt 확인"		
						fi		
					fi
				fi			
			else
				echo "[ /etc/snmp/snmpd.conf SNMP v1,v2,v3 확인 불가 ]"
				echo "SNMP_RAW_DATA.txt 확인"
				echo ""
				
				if [ `cat /etc/*-release | grep -i ubuntu | wc -l` -gt 0 ]; then # Ubuntu일 경우
					if [ -f /usr/share/snmp/snmpd.conf ]; then # /usr/share/snmp/snmpd.conf 파일 존재		
						echo "[ /usr/share/snmp/snmpd.conf v3 사용자 확인 ]"
						echo "SNMP_RAW_DATA.txt 확인"
						echo ""		
					else
						echo "[ /usr/share/snmp/snmpd.conf v3 사용자 확인 불가 ]"
						echo "SNMP_RAW_DATA.txt 확인"		
					fi		
				fi
			fi	
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ SNMP ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ SNMP ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			LB_GoodCase=1
			echo "[ SNMP ]"
			echo "SNMP SERVICE NOT ACTIVATE"
			echo ""
		fi

		echo ""
		echo "-------------------------------------------------------------------"
			if [ ${LB_BadCase} -eq 1 ]; then
				echo "[취약]"
				RESULT="BAD"
			elif [ ${LB_CheckCase1} -eq 1 ]; then
				echo "[확인] Config경로 확인"
				RESULT="CHECK"
			elif [ ${LB_CheckCase2} -eq 1 ]; then
				echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
				RESULT="CHECK"
			elif [ ${LB_CheckCase3} -eq 1 ]; then
				echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
				RESULT="CHECK"
			elif [ ${LB_CheckCase4} -eq 1 ]; then
				echo "[확인] SNMP_RAW_DATA.txt 확인"
				RESULT="CHECK"
			else
				echo "[양호] SNMP 서비스가 구동중이지 않음"
				RESULT="GOOD"
			fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_004(){
	{
		echo "양호: SMTP 서비스가 동작 중이지 않거나, 업무상 사용 중인 경우"
		echo "취약: 불필요한 SMTP 서비스가 동작 중인 경우"
	} > $STANDARD_FILE
	{
      LS_SMTPServices="sendmail postfix exim"
      LB_CheckCase1=0
      LB_CheckCase2=0
      LB_CheckCase3=0
      echo "-------------------------------------------------------------------"

      for LS_Service in ${LS_SMTPServices}; do
         
         PROCESS_CHECKER ${LS_Service}
         INETDON=0
         
         if [ ${PCK} -eq 1 ]; then
            LB_CheckCase1=1
         elif [ ${INETD_CONFGCK} -eq 2 ]; then
            LB_CheckCase2=1
            echo "[ ${LS_Service} ]"
            echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
            echo ""
         elif [ ${XINETD_CONFGCK} -eq 2 ]; then
            LB_CheckCase3=1
            echo "[ ${LS_Service} ]"
            echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
            echo ""
         else
            echo "[ ${LS_Service} ]"
            echo "${LS_Service} SERVICE NOT ACTIVATE"
            echo ""
         fi
      done
      
      INETDON=1
      
      echo "-------------------------------------------------------------------"
      if [ ${LB_CheckCase1} -eq 1 ]; then
         echo "[확인] SMTP 서비스가 구동중, 불필요한 서비스인지 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      elif [ ${LB_CheckCase2} -eq 1 ]; then
         echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      elif [ ${LB_CheckCase3} -eq 1 ]; then
         echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      else
         echo "[양호] SMTP 서비스가 구동중이지 않음"
         RESULT="GOOD"
      fi
      echo "-------------------------------------------------------------------"

	} > $STATUS_FILE 2> /dev/null
}

Unix_005(){
	{
		echo "양호: SMTP 서비스 미사용 또는, noexpn, novrfy 옵션이 설정되어 있는 경우"
		echo "취약: SMTP 서비스를 사용하고, noexpn, novrfy 옵션이 설정되어 있지 않는 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail PrivacyOptions option ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions'
						
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | grep -i 'goaway' | wc -l` -eq 0 ]; then
							if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | grep -i 'noexpn' | wc -l` -eq 0 -o `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | grep -i 'novrfy' | wc -l` -eq 0 ]; then
								LB_BadCase=1
							fi						
						fi
					else
						echo "PrivacyOptions OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
			done
			
			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail config FILE NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		# Postfix vrfy 명령 제한 점검
		PROCESS_CHECKER postfix
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Postfix VRFY 설정 ]"
			VRFY_SETTING=$(postconf disable_vrfy_command 2>/dev/null)
			echo "$VRFY_SETTING"
			if echo "$VRFY_SETTING" | grep -qi "yes"; then
				echo "[양호] disable_vrfy_command = yes"
			else
				echo "[취약] disable_vrfy_command 미설정 또는 no"
				LB_BadCase=1
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] 업무상 필요한 호스트에 대해서만 접근제어를 설정하고 있는지 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] SMTP 서비스가 expn, vrfy 명령어 사용을 허용하지 않고 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

check_syslog() {
	check_rsyslog=0
	# rsyslog 구동 확인
	if [ `systemctl is-active rsyslog` ]; then
		if [ -f "/etc/rsyslog.conf" ]; then
			echo "[ /etc/rsyslog.conf ]"
			cat /etc/rsyslog.conf | awk -F"#" '{print $1}' | grep -ie 'include\([^)]*\)' -ie '^\s*\$IncludeConfig'
			
			if [ -n "$rsysConf" ]; then
				echo $rsysConf
				check_rsyslog=1
			fi
			
			# rsyslogd 8.33 이상에서 inlcude 존재할 경우
			if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 1p` -ge 8 ]; then
				if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 2p` -ge 33 ]; then
					if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | wc -l` -gt 0 ]; then
						file_name=`cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | grep -oP 'file="\K[^"]+'`
						file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
						
						#파일이 존재할 경우
						echo ""
						echo "[ ls -a $file_name ]"
						ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
						if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' |wc -l` -gt 0 ]; then
							for file in ${file_list}; do
								#mail 확인
								if [ `cat ${file} | awk -F "#" '{print $1}' | grep -i "^mail" | wc -l` -gt 0 ]; then
									echo ""
									echo "[ $file ]"
									cat ${file} | awk -F "#" '{print $1}' | grep -i "^mail" | sed '/^$/d'
									check_rsyslog=1
								fi
							done
						else
							echo $file_name " : conf file does not exist"
							echo ""
						fi
					fi
				fi
			fi

			#includeconfig
			if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -i '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
				file_name=`cat /etc/rsyslog.conf | awk -F '#' '{print $1}' | grep -i '^\s*\$IncludeConfig' | awk '{print $2}'`
				file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`

				#파일이 존재할 경우
				echo ""
				echo "[ ls -a $file_name ]"
				ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
				if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' | wc -l` -gt 0 ]; then
					for file in ${file_list}; do
						#auth, authpriv 확인
						if [ `cat ${file} | awk -F "#" '{print $1}' | grep -i "^mail" | wc -l` -gt 0 ]; then
							echo ""
							echo "[ $file ]"
							cat ${file} | awk -F "#" '{print $1}' | grep -i "^mail" | sed '/^$/d'
							check_rsyslog=1
						fi
					done
				else
					echo $file_name " : conf file does not exist"
					echo ""
				fi
			fi

			if [ $check_rsyslog -eq 0 ]; then
				LB_BadCase=1
			fi
		else
			echo "rsyslog.conf, rsyslog.d NOT FOUND"
			LB_CheckCase1=1
		fi
		
	# syslog 구동 확인
	elif [ `systemctl is-active syslog` ]; then
		if [ -f "/etc/syslog.conf" ]; then
			echo "[ /etc/syslog.conf ]"
			
			if [ -n "$sysConf" ]; then
				echo $sysConf
			else
				echo "syslog path NOT FOUND"
				LB_BadCase=1	
			fi		
		else
			echo "syslog.conf NOT FOUND"
			LB_CheckCase1=1
		fi
	else
		echo "rsyslog, syslog NOT FOUND"
		LB_BadCase=1
	fi

}

Unix_006(){ # 로그레벨 설정값 9~15 양호로 점검
	{
		echo "양호: SMTP 로그 수준 설정이 적절한 경우"
		echo "취약: SMTP 로그 수준 설정이 낮은 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail LogLevel 설정 ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'LogLevel' | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'LogLevel'
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'LogLevel' | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then # null이 아님
							if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'LogLevel' | awk -F"=" '{print $2}'` -lt 9 -o `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'LogLevel' | awk -F"=" '{print $2}'` -gt 15 ]; then # 9미만, 15초과
								LB_BadCase=1
							fi
						else # NULL임
							LB_BadCase=1
						fi
					else
						echo "LogLevel OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
			done

			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail config FILE NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		PROCESS_CHECKER postfix
		
		
		version=$(postconf -d mail_version | awk -F"=" '{print $2}' | awk -F"." '{print ($1>=3 && $2>=4)}')

		mainConf=$(cat "/etc/postfix/main.cf" | grep -v '^#' | awk "/maillog_file *= */" | awk -F"=" '{print $2}')
		mainConf2=$(cat "/etc/postfix/main.cf" | grep -v '^#' | awk "/debug_peer_list *= */")
		mainConf3=$(cat "/etc/postfix/main.cf" | grep -v '^#' | awk "/debug_peer_level *= */" | tail -n 1) #맨 밑에 설정된 debug_peer_level 값만 가져옴
		rsysConf=$(cat "/etc/rsyslog.conf" | grep -v '^#' | grep -i "^mail")
		sysConf=$(cat "/etc/syslog.conf" | grep -v '^#' | grep -i "^mail")

		if [ ${PCK} -eq 1 ]; then
			
			echo "[ postfix Version ]"
			echo `postconf -d mail_version`
			
			echo ""
			echo "[ debug_peer_list ]"

			# debug_peer_list 설정 여부 확인
			commConf=$(echo "$mainConf2" | awk -F"=" '$2 ~ /[^ \t]/ {print $2}' | wc -l )
			# debug_peer_list = (공백)이 아닌 경우 양호
			if [ "$commConf" -eq 1 ]; then
				echo $mainConf2
			elif [ -z "$mainConf2" ]; then
				echo "debug_peer_list NOT FOUND"	
				LB_BadCase=1
			else
				echo $mainConf2
				LB_BadCase=1
			fi

			echo ""
			echo "[ debug_peer_level ]"

			# debug_peer_level 2 이상 확인
			commConf2=$(echo "$mainConf3" | awk -F"=" '$2 >= 2 {print $2}')
			if [ -n "$commConf2" ]; then
				echo $mainConf3
			elif [ -z "$mainConf3" ]; then
				echo "debug_peer_level NOT FOUND"
			else
				echo $mainConf3
				LB_BadCase=1
			fi
			echo ""
			
			# postfix 3.4버전 이상
			if [ $version -eq 1 ]; then
				# maillog_file 확인
				if [ -n "$mainConf" ]; then
					# maillog_file 경로 설정 확인ckle
					echo "[ /etc/postfix/main.cf maillog_file 설정값 ]"
					echo $mainConf
					echo ""
				# maillog_file 존재하지 않음
				else
					echo "maillog_file NOT FOUND"
					echo ""
					check_syslog 
				fi
				
			#3.4 version 미만일 경우
			else
				check_syslog 
			fi
			
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ postfix ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ postfix ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ postfix ]"
			echo "postfix SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi
		echo ""
		
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] SMTP 서비스의 LogLevel 설정이 양호함"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"

	} > $STATUS_FILE 2> /dev/null
}

Unix_007(){
	{
		echo "양호: 메일 서비스를 사용하지 않거나, 메일 서비스 버전이 최신 버전인 경우"
		echo "취약: 메일 서비스를 사용하고, 메일 서비스 버전이 최신 버전이 아닌 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LB_CheckCase5=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail Version ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | wc -l` -gt 0 ]; then 
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//'
							if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | grep '/' | wc -l` -gt 0 ]; then
								GS_SendmailVersion=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//' | awk -F"/" '{print $2}'`
								if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
									if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -eq 14 ]; then
										if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -lt 9 ]; then
											LB_CheckCase5=1               
										fi
									elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 14 ]; then
										LB_CheckCase5=1
									fi
								elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
									LB_CheckCase5=1
								fi
							else
								GS_SendmailVersion=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//'`
								if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
									if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -eq 14 ]; then
										if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -lt 9 ]; then
											LB_CheckCase5=1               
										fi
									elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 14 ]; then
										LB_CheckCase5=1
									fi
								elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
									LB_CheckCase5=1
								fi
							fi
					else
						echo "Sendmail Version NOT FOUND"
						LB_CheckCase4=1
					fi
				fi
			done
         
			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail Config File NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT FOUND"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		# Postfix 버전 점검
		PROCESS_CHECKER postfix
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Postfix Version ]"
			postconf mail_version 2>/dev/null || echo "postconf 명령 실행 불가"
			LB_CheckCase1=1
		fi

		# Exim 버전 점검
		PROCESS_CHECKER exim
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Exim Version ]"
			exim -bV 2>/dev/null | head -1 || echo "exim 명령 실행 불가"
			LB_CheckCase1=1
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase5} -eq 1 ]; then
			echo "[확인] 취약한 버전의 SMTP 서비스 사용, 내부 규정을 수립하여 패치를 적용하고 있는지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 확인할 수 없는 설정 파일이 존재하여 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] SMTP 서비스의 버전을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] 양호한 버전의 SMTP 서비스를 사용함"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

Unix_008(){ 
	{
		echo "양호: SMTP 서비스의 DoS 방지 관련 설정이 적용된 경우" 
		echo "취약: SMTP 서비스의 DoS 방지 관련 설정이 적용되지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail DoS deny option ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					
					LI_MDC=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MaxDaemonChildren' | awk -F"=" '{print $2}'`
					LI_CRT=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'ConnectionRateThrottle' | awk -F"=" '{print $2}'`
					LI_MFB=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MinFreeBlocks' | awk -F"=" '{print $2}'`
					LI_MHL=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MaxHeadersLength' | awk -F"=" '{print $2}'` # 8.9.3 이상
					LI_MHSL=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MAXHDRSLEN' | awk -F"=" '{print $2}'` # 8.9.3 미만
					LI_MMS=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MaxMessageSize' | awk -F"=" '{print $2}'`
					
					if [ `echo ${LI_MDC} | wc -w` -gt 0 ]; then
						cat ${LS_File} | grep -i 'MaxDaemonChildren'
						if [ ${LI_MDC} -gt 12 -o ${LI_MDC} -lt 0 ]; then
							LB_BadCase=1
						fi
					else
						echo "MaxDaemonChildren OPTION NOT FOUND"
						LB_BadCase=1
					fi
					
					if [ `echo ${LI_CRT} | wc -w` -gt 0 ]; then
						cat ${LS_File} | grep -i 'ConnectionRateThrottle'
						if [ ${LI_CRT} -gt 4 -o ${LI_CRT} -lt 0 ]; then
							LB_BadCase=1
						fi
					else
						echo "ConnectionRateThrottle OPTION NOT FOUND"
						LB_BadCase=1
					fi
					
					if [ `echo ${LI_MFB} | wc -w` -gt 0 ]; then
						cat ${LS_File} | grep -i 'MinFreeBlocks'
						if [ ${LI_MFB} -le 0 ]; then
							LB_BadCase=1
						fi
					else
						echo "MinFreeBlocks OPTION NOT FOUND"
						LB_BadCase=1
					fi
										
					if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
						if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -eq 9 ]; then
							if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -ge 3 ]; then
								if [ `echo ${LI_MHL} | wc -w` -gt 0 ]; then
									cat ${LS_File} | grep -i 'MaxHeadersLength'
									if [ ${LI_MHL} -gt 50000 -o ${LI_MHL} -lt 0 ]; then
										LB_BadCase=1
									fi
								else
									echo "MaxHeadersLength OPTION NOT FOUND"
									LB_BadCase=1
								fi
							elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -lt 3 ]; then
								if [ `echo ${LI_MHSL} | wc -w` -gt 0 ]; then
									cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MAXHDRSLEN'
									if [ ${LI_MHSL} -gt 50000 -o ${LI_MHSL} -lt 0 ]; then
										LB_BadCase=1
									fi
								else
									echo "MAXHDRSLEN OPTION NOT FOUND"
								fi
							fi
						elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -gt 9 ]; then
							if [ `echo ${LI_MHL} | wc -w` -gt 0 ]; then
								cat ${LS_File} | grep -i 'MaxHeadersLength'
								if [ ${LI_MHL} -gt 50000 -o ${LI_MHL} -lt 0 ]; then
									LB_BadCase=1
								fi
							else
								echo "MaxHeadersLength OPTION NOT FOUND"
								LB_BadCase=1
							fi
						elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 9 ]; then
							if [ `echo ${LI_MHSL} | wc -w` -gt 0 ]; then
								cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MAXHDRSLEN'
								if [ ${LI_MHSL} -gt 50000 -o ${LI_MHSL} -lt 0 ]; then
									LB_BadCase=1
								fi
							else
								echo "MAXHDRSLEN OPTION NOT FOUND"
							fi
						fi
					elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -gt 8 ]; then
						if [ `echo ${LI_MHL} | wc -w` -gt 0 ]; then
							cat ${LS_File} | grep -i 'MaxHeadersLength'
							if [ ${LI_MHL} -gt 50000 -o ${LI_MHL} -lt 0 ]; then
								LB_BadCase=1
							fi
						else
							echo "MaxHeadersLength OPTION NOT FOUND"
							LB_BadCase=1
						fi
					elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
						if [ `echo ${LI_MHSL} | wc -w` -gt 0 ]; then
							cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'MAXHDRSLEN'
							if [ ${LI_MHSL} -gt 50000 -o ${LI_MHSL} -lt 0 ]; then
								LB_BadCase=1
							fi
						else
							echo "MAXHDRSLEN OPTION NOT FOUND"
						fi
					fi
					
					if [ `echo ${LI_MMS} | wc -w` -gt 0 ]; then
						cat ${LS_File} | grep -i 'MaxMessageSize'
						if [ ${LI_MMS} -gt 1000000 -o ${LI_MMS} -le 0 ]; then
							LB_BadCase=1
						fi
					else
						echo "MaxMessageSize OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
			done

			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail OPTION NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		PROCESS_CHECKER postfix

		if [ ${PCK} -eq 1 ]; then
			echo "[ Postfix 설정 (/etc/postfix/main.cf) ]"
			if [ -f /etc/postfix/main.cf ]; then
				LI_DPL=`postconf default_process_limit | awk -F"=" '{print $2}'`
				LI_HSL=`postconf header_size_limit | awk -F"=" '{print $2}'`
				LI_MSL=`postconf message_size_limit | awk -F"=" '{print $2}'`
				LI_LDCL=`postconf local_destination_concurrency_limit | awk -F"=" '{print $2}'` 
				LI_SRL=`postconf smtpd_recipient_limit | awk -F"=" '{print $2}'`
				
				if [ `echo ${LI_DPL} | wc -w` -gt 0 ]; then
					postconf default_process_limit
					if [ ${LI_DPL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "default_process_limit OPTION NOT FOUND(Default: 100)"
				fi
												
				if [ `echo ${LI_HSL} | wc -w` -gt 0 ]; then
					postconf header_size_limit
					if [ ${LI_HSL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "header_size_limit OPTION NOT FOUND(Default: 102400)"
				fi
				
				if [ `echo ${LI_MSL} | wc -w` -gt 0 ]; then
					postconf message_size_limit
					if [ ${LI_MSL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "message_size_limit OPTION NOT FOUND(Default: 10240000)"
				fi

				if [ `echo ${LI_LDCL} | wc -w` -gt 0 ]; then
					postconf local_destination_concurrency_limit
					if [ ${LI_LDCL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "local_destination_concurrency_limit OPTION NOT FOUND(Default: 2)"
				fi

				if [ `echo ${LI_SRL} | wc -w` -gt 0 ]; then
					postconf smtpd_recipient_limit
					if [ ${LI_SRL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "smtpd_recipient_limit OPTION NOT FOUND(Default: 1000)"
				fi
				
			else
				LI_DPL=`postconf default_process_limit | awk -F"=" '{print $2}'`
				LI_HSL=`postconf header_size_limit | awk -F"=" '{print $2}'`
				LI_MSL=`postconf message_size_limit | awk -F"=" '{print $2}'`
				LI_LDCL=`postconf local_destination_concurrency_limit | awk -F"=" '{print $2}'` 
				LI_SRL=`postconf smtpd_recipient_limit | awk -F"=" '{print $2}'`
				
				if [ `echo ${LI_DPL} | wc -w` -gt 0 ]; then
					postconf default_process_limit
					if [ ${LI_DPL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "default_process_limit OPTION NOT FOUND(Default: 100)"
				fi
												
				if [ `echo ${LI_HSL} | wc -w` -gt 0 ]; then
					postconf header_size_limit
					if [ ${LI_HSL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "header_size_limit OPTION NOT FOUND(Default: 102400)"
				fi
				
				if [ `echo ${LI_MSL} | wc -w` -gt 0 ]; then
					postconf message_size_limit
					if [ ${LI_MSL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "message_size_limit OPTION NOT FOUND(Default: 10240000)"
				fi

				if [ `echo ${LI_LDCL} | wc -w` -gt 0 ]; then
					postconf local_destination_concurrency_limit
					if [ ${LI_LDCL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "local_destination_concurrency_limit OPTION NOT FOUND(Default: 2)"
				fi

				if [ `echo ${LI_SRL} | wc -w` -gt 0 ]; then
					postconf smtpd_recipient_limit
					if [ ${LI_SRL} -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					echo "smtpd_recipient_limit OPTION NOT FOUND(Default: 1000)"
				fi
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ postfix ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ postfix ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ postfix ]"
			echo "postfix SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] SMTP 서비스의 DoS 방지 관련 설정이 적용되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

Unix_009(){
	{
		echo "양호: 메일 서비스 미사용 또는, 릴레이 제한이 설정된 경우"
		echo "취약: 메일 서비스를 사용하고, 릴레이 제한이 설정되어 있지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail relaying denied option ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
						if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 9 ]; then
							if [ `cat ${LS_File} | grep -v '^#' | grep "R$\*" | grep -i "Relaying denied" | wc -l` -gt 0 ]; then
								cat ${LS_File} | grep "R$\*" | grep -i "Relaying denied"
							else
								echo "Relaying denied OPTION NOT FOUND"
								LB_BadCase=1
							fi
						else
							if [ -f '/etc/mail/sendmail.mc' ]; then
								if [ `cat /etc/mail/sendmail.mc | grep -v "^#" | awk -F"dnl" '{print $1}' | grep -i "promiscuous_relay" | wc -l` -gt 0 ]; then
									echo "sendmail.mc promiscuous_relay : `cat /etc/mail/sendmail.mc | grep -v "^#" | awk -F"dnl" '{print $1}' | grep -i "promiscuous_relay"`"
									LB_BadCase=1
								else
									echo "version : ${GS_SendmailVersion} Default Good"
								fi
							elif [ -f '/etc/sendmail.mc' ]; then
								if [ `cat /etc/sendmail.mc | grep -v "^#" | awk -F"dnl" '{print $1}' | grep -i "promiscuous_relay" | wc -l` -gt 0 ]; then
									echo "sendmail.mc promiscuous_relay : `cat /etc/sendmail.mc | grep -v "^#" | awk -F"dnl" '{print $1}' | grep -i "promiscuous_relay"`"
									LB_BadCase=1
								else
									echo "version : ${GS_SendmailVersion} Default Good"
								fi
							else
								echo "Sendmail CONFIG 'mc' FILT NOT FOUND"
								LB_CheckCase5=1
							fi
						fi
					elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
						if [ `cat ${LS_File} | grep -v '^#' | grep "R$\*" | grep -i "Relaying denied" | wc -l` -gt 0 ]; then
							cat ${LS_File} | grep "R$\*" | grep -i "Relaying denied"
						else
							echo "Relaying denied OPTION NOT FOUND"
							LB_BadCase=1
						fi
					else
						echo "Version ${GS_SendmailVersion} Default good"
					fi
				fi
			done
			
			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail 설정 파일이 존재하지 않음"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		# Postfix 릴레이 설정 점검
		PROCESS_CHECKER postfix
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Postfix Relay 설정 ]"
			echo "** mynetworks **"
			postconf mynetworks 2>/dev/null
			echo "** smtpd_relay_restrictions **"
			postconf smtpd_relay_restrictions 2>/dev/null
			LB_CheckCase1=1
		fi

		# Exim 릴레이 설정 점검
		PROCESS_CHECKER exim
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Exim Relay 설정 ]"
			if [ -f /etc/exim4/exim4.conf ]; then
				grep -i "relay_from_hosts\|host_accept_relay" /etc/exim4/exim4.conf 2>/dev/null
			elif [ -f /etc/exim/exim.conf ]; then
				grep -i "relay_from_hosts\|host_accept_relay" /etc/exim/exim.conf 2>/dev/null
			fi
			LB_CheckCase1=1
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] Postfix 로우데이터 확인 및 설정된 릴레이 방지 옵션에 대한 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase5} -eq 1 ]; then
			echo "[확인] Exim 로우데이터 확인 및 설정된 릴레이 방지 옵션에 대한 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] SMTP 서비스에 스팸 메일 릴레이 방지 설정이 되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

Unix_010(){
	{
		echo "양호: 일반 사용자의 메일 서비스 실행 방지가 설정된 경우"
		echo "취약: 일반 사용자의 메일 서비스 실행 방지가 설정되어 있지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail PrivacyOptions config ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions'
						LB_GoodCase=`expr ${LB_GoodCase} + 1`
						
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'PrivacyOptions' | grep -i 'restrictqrun' | wc -l` -eq 0 ]; then
							LB_BadCase=1
						fi
					else
						echo "PrivacyOptions OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
			done
			
			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail config FILE NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT FOUND"
			echo ""
			#LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi

		# Postfix 실행 권한 점검
		if [ -f /usr/sbin/postsuper ]; then
			echo ""
			echo "[ Postfix postsuper 실행 권한 ]"
			ls -l /usr/sbin/postsuper
			if [ `ls -l /usr/sbin/postsuper | awk '{print $1}' | cut -c8` != "-" ]; then
				echo "[취약] other 사용자에 postsuper 실행 권한 존재"
				LB_BadCase=1
			else
				echo "[양호] other 사용자에 postsuper 실행 권한 없음"
			fi
		fi

		# Exim 실행 권한 점검
		if [ -f /usr/sbin/exiqgrep ]; then
			echo ""
			echo "[ Exim exiqgrep 실행 권한 ]"
			ls -l /usr/sbin/exiqgrep
			if [ `ls -l /usr/sbin/exiqgrep | awk '{print $1}' | cut -c8` != "-" ]; then
				echo "[취약] other 사용자에 exiqgrep 실행 권한 존재"
				LB_BadCase=1
			else
				echo "[양호] other 사용자에 exiqgrep 실행 권한 없음"
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then 
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -gt 0 ] && [ ${LB_GoodCase} -le 3 ]; then
			#echo "[양호] SMTP 서비스를 사용하지 않음"
			echo "[양호] SMTP 서비스의 메일 queue 처리 권한을 업무 관리자에게만 부여되도록 설정되어 있음"
			RESULT="GOOD"
		else
			#echo "[양호] SMTP 서비스의 메일 queue 처리 권한을 업무 관리자에게만 부여되도록 설정되어 있음"
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}



Unix_011(){
	{
		echo "양호 : FTP 서비스가 비활성화 되어 있거나, 활성화 시 root 계정 접속을 차단 한 경우" 
		echo "취약 : FTP 서비스가 활성화 되어 있고, root 계정 접속을 허용한 경우" 
	} > $STANDARD_FILE
	{	

		LI_ConfExist=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_GoodCase=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "ftp"
		LS_Result=`PROCESS_CHECKER "ftp"` 
		if [ ${PCK} -eq 1 ]; then
			if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
				for LS_File1 in ${GS_VsFTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						if [ `cat ${LS_File1} | awk -F"#" '{print $1}' | grep -w "root" | wc -l` -gt 0 ]; then
							LI_ConfExist=1
						fi

						echo "[ ${LS_File1} ]"
						if [ `cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w ` -gt 0 ]; then
							cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d'
						else
							echo "This File is Empty"
						fi
						echo ""
					fi
				done

				if [ ${LI_FileExist} -eq 0 ]; then
						echo "[ ftpusers ]"
						echo "ftpusers FILE NOT FOUND"
						echo ""
				fi
				LI_FileExist=0
				LI_FileExist1=0

				if [ ${LI_ConfExist} -eq 0 ]; then
					for LS_File1 in ${GS_VsFTPConf}; do
						if [ -f ${LS_File1} ]; then
							LI_FileExist=1
							LS_Config=`cat ${LS_File1} | awk -F"#" '{print $1}' | grep "userlist_enable"`
							echo "[ ${LS_File1} ]"
							if [ `echo ${LS_Config} | wc -l` -gt 0 ]; then
								echo ${LS_Config}
								echo ""
								if [ `echo ${LS_Config} | awk -F"=" '{print $2}' | grep -i "YES" | wc -l` -gt 0 ]; then
									for LS_File2 in ${GS_VsFTPUserList}; do
										if [ -f ${LS_File2} ]; then
											LI_FileExist1=1
											echo "[ ${LS_File2} ]"
											if [ `cat ${LS_File2} | awk -F"#" '{print $1}' | grep -w "root" | wc -l` -eq 0 ]; then
												LB_BadCase=1
											fi

											echo "[ ${LS_File2} ]"
											if [ `cat "${LS_File2}" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w ` -gt 0 ]; then
												cat "${LS_File2}" | awk -F"#" '{print $1}' | sed '/^$/d'
											else
												echo "This File is Empty"
											fi
											echo ""
										fi
									done

									if [ ${LI_FileExist1} -eq 0 ]; then
										echo "[ user_list file ]"
										echo "user_list FILE NOT FOUND"
										echo ""
									fi
								else
									LB_BadCase=1
								fi
							else
								echo "userlist_enable OPTION NOT FOUND"
								echo ""
								LB_BadCase=1
							fi
							# userlist_enable의 값이 비어있거나 YES,NO가 아닌 다른 문자열이 있을 경우 ftp 실행이 안됨
						fi
					done

					if [ ${LI_FileExist} -eq 0 ]; then
						LB_CheckCase1=1
						echo "[ vsftpd.conf ]"
						echo "ftp config FILE NOT FOUND"
						echo ""
					fi
				fi
			elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then
				for LS_File1 in ${GS_ProFTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						if [ `cat ${LS_File1} | awk -F"#" '{print $1}' | grep -w "root" | wc -l` -gt 0 ]; then
							LI_ConfExist=1
						fi

						echo "[ ${LS_File1} ]"
						if [ `cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w ` -gt 0 ]; then
							cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d'
						else
							echo "This File is Empty"
						fi
						echo ""
					fi
				done
				if [ ${LI_FileExist} -eq 0 ]; then
						echo "[ ftpusers ]"
						echo "ftpusers FILE NOT FOUND"
						echo ""
				fi

				LI_FileExist=0

				if [ ${LI_ConfExist} -eq 0 ]; then
					for LS_File1 in ${GS_ProFTPConf}; do
						if [ -f ${LS_File1} ]; then
							LI_FileExist=1
							echo "[ ${LS_File1} ]"
							LS_Config=`cat ${LS_File1} | awk -F"#" '{print $1}' | grep -i "RootLogin"`
							if [ `echo ${LS_Config} | wc -w` -gt 0 ]; then
								echo ${LS_Config}
								echo ""
								if [ `echo ${LS_Config} | grep -i on | wc -l` -gt 0 ]; then
									LB_BadCase=1
								fi
							else
								echo "RootLogin CONFIG NOT FOUND (default : off)"
							fi
						fi
					done

					if [ ${LI_FileExist} -eq 0 ]; then
						echo "[ proftpd.conf ]"
						echo "ftp config FILE NOT FOUND"
						echo ""
					fi
				fi
			else 
				for LS_File1 in ${GS_FTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						if [ `cat ${LS_File1} | awk -F"#" '{print $1}' | grep -w "root" | wc -l` -gt 0 ]; then
							LI_ConfExist=1
						else
							LB_BadCase=1
						fi
						echo "[ ${LS_File1} ]"
						if [ `cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w ` -gt 0 ]; then
							cat "${LS_File1}" | awk -F"#" '{print $1}' | sed '/^$/d'
						else
							echo "This File is Empty"
						fi
						echo ""
					fi
				done
				if [ ${LI_FileExist} -eq 0 ]; then
						echo "[ ftpusers ]"
						echo "ftpusers FILE NOT FOUND"
						echo ""
						LB_BadCase=1
				fi
			fi
			
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp SERVICE NOT FOUND"
			echo ""
			LB_GoodCase=1
		fi
		
		echo "-------------------------------------------------------------------"		
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LB_CheckCase1}" -eq 1 ]; then 
			echo "[확인] FTP 설정 파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ "${LB_CheckCase2}" -eq 1 ]; then 
			echo "[확인] inetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ "${LB_CheckCase3}" -eq 1 ]; then 
			echo "[확인] xinetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ "${LB_GoodCase}" -eq 1 ]; then
			echo "[양호] FTP 서비스가 구동중이지 않음"
			RESULT="GOOD"
		else
			echo "[양호] FTP root 로그인을 허용하지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_012(){
	{
		echo "양호: .netrc 파일 내부에 아이디,패스워드 등 민감한 정보가 없는 경우" 
		echo "취약: .netrc 파일 내부에 아이디,패스워드 등 민감한 정보가 있는 경우" 
	} > $STANDARD_FILE
	
	{	
		if [ -f ${GS_PasswdConf} ]; then
			HOMEDIRS=`cat ${FILE} | grep -v "/bin/false" | grep -v "/sbin/nologin" | awk -F":" 'length($6) > 0 {print $6}' | sort -u`
		fi
		
		BADCASE=0
		CNT=0
		echo "-------------------------------------------------------------------"
		for HOME in ${HOMEDIRS}; do
			NETRC=${HOME}/.netrc
			if [ -f ${NETRC} ]; then
				CNT=$(($CNT+1))
				echo "[ .netrc File Contents (${NETRC}) ]"
				if [ `cat ${NETRC} | grep -v "^#" | grep -i 'password' | wc -l` -gt 0 ]; then
					cat ${NETRC} | grep -v "^#" | grep -i 'password'
					BADCASE=1
				else
					echo "${NETRC} password NOT FOUND"
				fi					
			fi
		done
		
		if [ "${CNT}" -eq 0 ]; then
			echo ".netrc File NOT FOUND"
		fi
				
		echo "-------------------------------------------------------------------"
		if [ "${CNT}" -eq 0 ]; then
			echo "[양호] .netrc 파일이 존재하지 않음"
			RESULT="GOOD"
		else
			if [ "${BADCASE}" -gt 0 ]; then
				#echo "[취약] .netrc 파일에 계정 정보가 존재함"
				echo "[취약] "
				RESULT="BAD"
			else
				echo "[양호] .netrc 파일이 존재하나 내용이 없고 계정정보가 평문으로 저장되어 있지 않음"
				RESULT="GOOD"
			fi
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}



Unix_013(){
   {
      echo "양호: 공유 서비스에 대해 익명 접근을 제한한 경우"
      echo "취약: 공유 서비스에 대해 익명 접근을 허용한 경우"
      
   } > $STANDARD_FILE
   
   {   
      LI_ConfExist=0
      LB_BadCase=0
      LB_CheckCase1=0
      LB_CheckCase2=0
      LB_CheckCase3=0
	  LB_CheckCase4=0
	  LB_GoodCase=0
      LI_FileExist=0
      echo "-------------------------------------------------------------------"
      PROCESS_CHECKER "ftp"
      LS_Result=`PROCESS_CHECKER "ftp"` 
      if [ ${PCK} -eq 1 ]; then
         if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
            
            for LS_File1 in ${GS_VsFTPConf}; do
                if [ -f ${LS_File1} ]; then
                  LI_FileExist=1
                  LS_Config=`cat ${LS_File1} | awk -F"#" '{print $1}' | grep -i "anonymous_enable"`
                  echo "[ ${LS_File1} ]"
                  if [ `echo ${LS_Config} | wc -l` -gt 0 ]; then
                     echo ${LS_Config}
                     echo ""
                     if [ `echo ${LS_Config} | awk -F"=" '{print $2}' | grep -i "YES" | wc -l` -gt 0 ]; then
                        LB_BadCase=1
                     fi
                  else
                     echo "anonymous_enable CONFIG NOT FOUND ( default : YES )"
                     echo ""
                     LB_BadCase=1
                  fi
                  # userlist_enable의 값이 비어있거나 YES,NO가 아닌 다른 문자열이 있을 경우 ftp 실행이 안됨
                fi
            done

            if [ ${LI_FileExist} -eq 0 ]; then
               LB_CheckCase1=1
               echo "[ vsftpd.conf ]"
               echo "ftp config FILE NOT FOUND"
               echo ""
            fi
         
         elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then
            
            for LS_File1 in ${GS_ProFTPConf}; do
               if [ -f ${LS_File1} ]; then
                  LI_FileExist=1
                  
				LS_Config=`cat ${LS_File1} | awk -F"#" '{print $1}' | awk 'BEGIN{ defTag=0; anonTag=0}{
					if ( defTag==0 && modTag==0 && anonTag==0 )
					{

						if ( match($0, "<IfDefine")>0 )
						{
							defTag=1
							print $0
						}
						else if ( match($0, "<Anonymous")>0 )
						{
							anonTag=1
							print $0
						}
						else if ( match($0, "Define")>0 )
						{
							print $0
						}
						else if ( match($0, "Include")>0 )
						{
							print $0
						}
					}
					else if (defTag==1)
					{
						print $0	
						if ( match($0, "</IfDefine")>0 )
						{
							defTag=0
						}
					}
					else if (anonTag==1)
					{
						print $0	
						if ( match($0, "</Anonymous")>0 )
						{
							anonTag=0
						}
					}	
				}'`

				echo "[ ${LS_File1} ]"
				echo "${LS_Config}"
				echo ""

				LS_IncludeFiles=`echo "${LS_Config}" | grep "Include" | awk '{print $2}'`

				for LS_IncludeFile in ${LS_IncludeFiles}; do
				echo "${LS_IncludeFile} file check"
				done
				
				LB_CheckCase4=1

               fi
            done

            if [ ${LI_FileExist} -eq 0 ]; then
               echo "[ proftpd.conf ]"
               echo "ftp config FILE NOT FOUND"
               echo ""
            fi
            
         else 
            if [ -f "/etc/passwd" ]; then
               echo "[ /etc/passwd ]"
               if [ `cat "/etc/passwd" | grep -wi "ftp" | wc -l` -gt 0 ]; then
				  cat "/etc/passwd" | grep -w "ftp" | awk -F":" '{print $1":"$7}'
                  LB_BadCase=1
               else
				  echo "ftp NOT FOUND"
			   fi
            else
               echo "[ /etc/passwd ]"
               echo "FILE NOT FOUND"
               echo ""
               LB_CheckCase1=1
            fi
         fi
         
      elif [ ${INETD_CONFGCK} -eq 2 ]; then
         LB_CheckCase2=1
         echo "[ ftp ]"
         echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
         echo ""
      elif [ ${XINETD_CONFGCK} -eq 2 ]; then
         LB_CheckCase3=1
         echo "[ ftp ]"
         echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
         echo ""
      else
         echo "[ ftp ]"
         echo "ftp SERVICE NOT ACTIVATE"
         echo ""
         LB_GoodCase=1
      fi

		# NFS 익명 접근 점검
		echo ""
		echo "[ NFS 익명 접근 설정 ]"
		if [ -f /etc/exports ]; then
			echo "** /etc/exports **"
			cat /etc/exports
			# insecure 또는 anonuid=0 확인
			if grep -v "^#" /etc/exports 2>/dev/null | grep -qi "insecure\|anonuid=0\|anon=0"; then
				echo "[취약] NFS 익명 접근 허용 설정 존재"
				LB_BadCase=1
			fi
		else
			echo "/etc/exports 파일 없음 (NFS 미사용)"
		fi

		# Samba 익명 접근 점검
		echo ""
		echo "[ Samba 익명 접근 설정 ]"
		PROCESS_CHECKER smbd
		if [ ${PCK} -eq 1 ]; then
			SMB_CONF=""
			for CONF in /etc/samba/smb.conf /etc/smb.conf /usr/local/samba/lib/smb.conf; do
				if [ -f "$CONF" ]; then
					SMB_CONF="$CONF"
					break
				fi
			done
			if [ -n "$SMB_CONF" ]; then
				echo "** $SMB_CONF **"
				grep -i "guest ok\|public\|map to guest" "$SMB_CONF" 2>/dev/null | grep -v "^[;#]"
				if grep -v "^[;#]" "$SMB_CONF" 2>/dev/null | grep -qi "guest ok.*=.*yes\|public.*=.*yes"; then
					echo "[취약] Samba 게스트 접근 허용"
					LB_BadCase=1
				else
					echo "[양호] Samba 게스트 접근 차단"
				fi
			fi
		else
			echo "Samba 서비스 미구동"
		fi

      echo "-------------------------------------------------------------------"
      if [ "${LB_BadCase}" -gt 0 ]; then
         echo "[취약]"
         RESULT="BAD"
      elif [ "${LB_CheckCase1}" -eq 1 ]; then
         echo "[확인] 설정 파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
         RESULT="CHECK"
      elif [ "${LB_CheckCase2}" -eq 1 ]; then
         echo "[확인] inetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
         RESULT="CHECK"
      elif [ "${LB_CheckCase3}" -eq 1 ]; then
         echo "[확인] xinetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
         RESULT="CHECK"
	  elif [ "${LB_CheckCase4}" -eq 1 ]; then
         echo "[확인] 현황을 참고하여 수동점검 필요"
         RESULT="CHECK"
      elif [ "${LB_GoodCase}" -eq 1 ]; then
		 echo "[양호] FTP 서비스가 구동중이지 않음"
		 RESULT="GOOD"
      else
         echo "[양호] FTP Anonymous 로그인을 허용하지 않음"
         RESULT="GOOD"
      fi
      echo "-------------------------------------------------------------------"
   } > $STATUS_FILE
}

Unix_014(){
	{
		echo "양호: 불필요한 NFS 서비스를 사용하지 않거나, 불가피하게 사용 시 everyone 공유를 제한한 경우" 
		echo "취약: 불필요한 NFS 서비스를 사용하고 있고, everyone 공유를 제한하지 않은 경우" 
	} > $STANDARD_FILE
	
	{
		LI_FileExist=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_BadCase=0
		LB_GoodCase=0
		LI_ProcessExist=0
		LS_NfsdConf="/etc/exports"
		echo "-------------------------------------------------------------------"
		LS_NFSServices="nfsd statd lockd"
		
		PROCESS_CHECKER "nfsd" 1>/dev/null
		if [ "${PCK}" -eq 0 ]; then
			echo "[ nfsd ]"
			echo "NFS SERVICE NOT ACTIVATE"
		else
			for LS_Service in ${LS_NFSServices}; do
				
				PROCESS_CHECKER ${LS_Service}
				INETDON=0
				
				if [ "${PCK}" -gt 0 ]; then
					LI_ProcessExist=1
				elif [ ${INETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase2=1
					echo "[ ${LS_Service} ]"
					echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
					echo ""
				elif [ ${XINETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase3=1
					echo "[ ${LS_Service} ]"
					echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
					echo ""
				else
					echo "[ ${LS_Service} ]"
					echo "${LS_Service} SERVICE NOT ACTIVATE"
					echo ""
				fi
			done
		fi
		
		if [ ${LI_ProcessExist} -eq 1 ]; then
			if [ -f ${LS_NfsdConf} ]; then
				LS_Config=`cat ${LS_NfsdConf} | grep "\/[a-z]*"`
				if [ `echo ${LS_Config} | wc -w` -gt 0 ]; then
					if [ `echo "${LS_Config}" | grep "\*" | wc -l` -gt 0 ]; then
						echo "[ ${LS_NfsdConf} ]"
						echo "${LS_Config}"
						echo ""
						LB_BadCase=1
					fi
				else
					LB_GoodCase=1
					echo "[ ${LS_NfsdConf} ]"
					echo "OPTION NOT FOUND"
					echo ""
				fi

				# /etc/exports 파일 소유자 및 권한 점검 (root 소유, 644 이하)
				echo "[ ${LS_NfsdConf} 파일 권한 ]"
				ls -l ${LS_NfsdConf}
				EXPORTS_OWNER=`ls -l ${LS_NfsdConf} | awk '{print $3}'`
				EXPORTS_PERM=`stat -c '%a' ${LS_NfsdConf} 2>/dev/null`
				if [ "${EXPORTS_OWNER}" != "root" ]; then
					echo "[취약] ${LS_NfsdConf} 소유자가 root가 아님 (${EXPORTS_OWNER})"
					LB_BadCase=1
				elif [ -n "${EXPORTS_PERM}" ] && [ "${EXPORTS_PERM}" -gt 644 ] 2>/dev/null; then
					echo "[취약] ${LS_NfsdConf} 권한이 644 초과 (${EXPORTS_PERM})"
					LB_BadCase=1
				else
					echo "[양호] ${LS_NfsdConf} 소유자: ${EXPORTS_OWNER}, 권한: ${EXPORTS_PERM}"
				fi
				echo ""
			else
				LB_CheckCase1=1
				echo "[ ${LS_NfsdConf} ]"
				echo "FILE NOT FOUND"
				echo ""
			fi
		fi
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] 설정 파일이 존재하지 않아 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_GoodCase} -eq 1 ]; then
			echo "[양호] NFS가 실행중이지만 공유 중인 디렉터리가 존재하지 않음"
			RESULT="GOOD"
		elif [ ${LI_ProcessExist} -eq 0 ]; then
			echo "[양호] NFS 서비스가 사용중이지 않음"
			RESULT="GOOD"
		else
			echo "[양호] NFS 비활성화 혹은 적절한 접근통제가 이루어지고 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_015(){
	{
		echo "양호: 불필요한 NFS 서비스 관련 데몬이 비활성화된 경우"
		echo "취약: 불필요한 NFS 서비스 관련 데몬이 활성화된 경우" 
	} > $STANDARD_FILE
	
	{
		LB_CheckCase1=0
		LB_CheckCase2=0		
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		LS_NFSServices="nfsd statd lockd"
		
		PROCESS_CHECKER "nfsd" 1>/dev/null
		if [ "${PCK}" -eq 0 ]; then
			echo "[ nfsd ]"
			echo "NFS SERVICE NOT ACTIVATE"
		else
			for LS_Service in ${LS_NFSServices}; do
				
				PROCESS_CHECKER ${LS_Service}
				INETDON=0
				
				if [ "${PCK}" -gt 0 ]; then
					LB_CheckCase1=1
				elif [ ${INETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase2=1
					echo "[ ${LS_Service} ]"
					echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
					echo ""
				elif [ ${XINETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase3=1
					echo "[ ${LS_Service} ]"
					echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
					echo ""
				else
					echo "[ ${LS_Service} ]"
					echo "${LS_Service} SERVICE NOT ACTIVATE"
					echo ""
				fi
			done
		fi
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] NFS 서비스가 필요에 의해 운영되고 있는지 담당자와의 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
		else
			echo "[양호] NFS 서비스가 사용중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_016(){
	{
		echo "양호: 불필요한 RPC 서비스가 비활성화된 경우"
		echo "취약: 불필요한 RPC 서비스가 활성화된 경우" 
	} > $STANDARD_FILE
	
	{
		LS_RPCServices="rpc.cmsd rpc.ttdbserverd sadmind rusersd walld sprayd rstatd rpc.nisd rexd rpc.pcnfsd rpc.statd rpc.ypupdated rpc.rquotad kcms_server cachefsd"
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		for LS_Service in ${LS_RPCServices}; do
			
			PROCESS_CHECKER ${LS_Service}
			INETDON=0
			
			if [ ${PCK} -eq 1 ]; then
				LB_CheckCase1=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} SERVICE NOT ACTIVATE"
				echo ""
			fi
		done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] RPC 서비스가 구동중, 불필요한 서비스인지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] RPC 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_021(){
	{
		echo "양호: 특정 IP 주소 또는 호스트에서만 FTP 서버에 접속하도록 접근제어 설정을 적용한 경우"
		echo "취약: 특정 IP 주소 또는 호스트에서만 FTP 서버에 접속하도록 접근제어 설정을 적용하지 않은 경우" 
	} > $STANDARD_FILE
	{	############## ftpaccess ftphosts 파일 검증 해야함
		LB_BadCase=0
		LB_CheckCase=0
		LI_ContentExist=0
        LI_FileExist1=0
        LI_FileExist2=0
        LI_FileExist3=0
        LI_FileExist4=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER ftp
		LS_Result=`PROCESS_CHECKER ftp` 

		if [ ${PCK} -eq 1 ]; then
			if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
				for LS_File1 in ${GS_VsFTPConf}; do
					 				
					if [ -f ${LS_File1} ]; then 
						echo "[ vsFTP access control ]"
						LI_FileExist1=1					
						if [ `cat ${LS_File1} | grep -i 'tcp_wrappers' | grep -v '^#' | wc -l` -gt 0 ]; then 
							echo "${LS_File1} : " 
							cat ${LS_File1} | grep -i 'tcp_wrappers' 
							echo "" 
						else
							echo "${LS_File1} : 'tcp_wrappers' OPTIONS NOT FOUND"
							echo ""
                            LB_BadCase=1
						fi 			
					else 
						echo ""
					fi 
				done 

				if [ ${LI_FileExist1} -eq 0 ]; then
					echo "vsFTP conf FILE NOT FOUND"
					echo ""
                    LB_CheckCase=1
				fi
			elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then 
				for LS_File2 in ${GS_ProFTPConf}; do
									
					if [ -f ${LS_File2} ]; then 
						echo "[ cat /proFTP access control ]" 
						LI_FileExist2=1						
						if [ `cat ${LS_File2} | sed '/<[Aa]nonymous/,/[Aa]nonymous>/d' | awk '/<[Ll][Ii][Mm][Ii][Tt] [Ll][Oo][Gg][Ii][Nn]>/,/[Ll][Ii][Mm][Ii][Tt]>/' | wc -l` -gt 0 ]; then 
							cat ${LS_File2} | sed '/<[Aa]nonymous/,/[Aa]nonymous>/d' | awk '/<[Ll][Ii][Mm][Ii][Tt] [Ll][Oo][Gg][Ii][Nn]>/,/[Ll][Ii][Mm][Ii][Tt]>/' 		
							echo "" 
						else
							echo "${LS_File2} : <Limit login> TAG NOT FOUND"
                            LB_BadCase=1
							echo ""
						fi 
					fi 
				done 
				if [ ${LI_FileExist2} -eq 0 ]; then
					echo "[ cat /proFTP access control ]"
					echo "proFTP FILE NOT FOUND"
					echo ""
                    LB_CheckCase=1
				fi

			else 				
				for LS_File3 in ${GS_FTPAccessConf}; do
									
					if [ -f ${LS_File3} ]; then 
						echo "[ cat /FTP access control (ftpaccess) ]"
						LI_FileExist3=1					
						if [ `cat ${LS_File3} | grep -i '^class' | grep -v '^#' | awk -F" " '{print $4}' | grep -v "^*" |wc -l` -gt 0 ]; then 
							cat ${LS_File3} | grep -i 'class' 
							echo "" 
						else
                            cat ${LS_File3} | grep -i '^class'
							echo ""

                            for LS_File4 in ${GS_FTPHostsConf}; do
                                
                                if [ -f ${LS_File4} ]; then
									echo "[ cat /FTP acceess control File(ftphosts) ]"
                                    LI_FileExist4=1
                                    if [ `cat ${LS_File4} | grep -v "^#" | grep -v "^$" | wc -l` -gt 0 ]; then
                                        cat ${LS_File4} | grep -v "^#" | grep -v "^$"
                                        echo ""
                                    else
                                        cat ${LS_File4} | grep -v "^$"
							            echo ""
                                        LB_BadCase=1
                                    fi
                                else
                                    
						            echo ""
                                    LB_BadCase=1
						        fi
								
                            done
							if [ ${LI_FileExist4} -eq 0 ]; then
									echo "[ cat /FTP access control (ftphosts) ]"
									echo "ftphosts FILE NOT FOUND"
									echo ""
									LB_CheckCase=1
							fi 
                        fi
					else
						echo ""
					fi 
				done
				if [ ${LI_FileExist3} -eq 0 ]; then
					echo "[ cat /FTP access control (ftpaccess) ]"
					echo "ftpaccess FILE NOT FOUND"
					echo ""
                    LB_CheckCase=1
				fi
				
			fi		

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp service not found"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then	
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase} -eq 1 ]; then
			echo "[확인] 설정 파일을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] FTP 서비스 내 접근제어 설정이 적절하게 이루어져 있음"
			RESULT="GOOD"
		fi	
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_022(){
	{
		echo "양호: 계정들의 비밀번호가 모두 설정되어 있을 경우"
		echo "취약: 비밀번호가 설정되지 않은 계정이 존재할 경우" 
	} > $STANDARD_FILE

	{	
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ No password account (${GS_ShadowConf}) ]"
		
		if [ -f "/etc/passwd" -a -f "/etc/shadow" ]; then
			LS_Users=`cat /etc/passwd | awk -F"#" '{print $1}' | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F':' '{print $1}'`
			for LS_User in ${LS_Users}; do
				if [ `cat ${GS_ShadowConf} | grep -w ${LS_User} | awk -F':' '{print $2}' | grep -w '\!\!' | wc -l` -ge 1 -o `cat ${GS_ShadowConf} | grep -w ${LS_User} | awk -F':' '{print $2}' | wc -w` -eq 0 ]; then
					LB_BadCase=1
				fi
				cat ${GS_ShadowConf} | grep -w ${LS_User}
			done
		else
			echo "/etc/passwd or /etc/shadow FILE NOT FOUND"
			LB_CheckCase=1
		fi
		echo "-------------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LB_CheckCase}" -gt 0 ]; then
			echo "[확인] 계정 패스워드 설정파일이 존재하지 않음 담당자의 인터뷰가 필요함"
			RESULT="CHECK"
		else
			echo "[양호] 시스템에 로그인할 수 있는 모든 계정의 패스워드가 설정"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_025(){
	{

		echo "양호: /etc/hosts.equiv, 각 계정들의 \$HOME/.rhosts 파일이 없을 경우 혹은 신뢰된 호스트들의 목록만 가지고 있을 경우"
		echo "취약: /etc/hosts.equiv 또는 각 계정들의 \$HOME/.rhosts 파일에 '+' 설정이나 불필요한 계정/호스트 IP가 존재할 경우"

	} > $STANDARD_FILE
		
	{

		LB_BadCase=0
		LI_FileExist=0
		LB_GoodCase=0
		echo "-------------------------------------------------------------------"
		echo "[ ${HOSTS_EQUIV} File ]"
		if [ -f ${HOSTS_EQUIV} ]; then
			LI_FileExist=1
			
			if [ `cat ${HOSTS_EQUIV} | awk -F'#' '{print $1}' | grep '\+' | wc -l` -gt 0 ]; then
				cat ${HOSTS_EQUIV} | awk -F'#' '{print $1}' | grep '\+'
				LB_BadCase=1
			else
				echo "\+ OPTION NOT FOUND"
			fi
		else
			echo "/etc/hosts.equiv NOT FOUND"
			echo ""
		fi
		
		LS_HomeDir=`cat /etc/passwd | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F":" '{print $6}' | sort | uniq`
		for LS_Dir in ${LS_HomeDir}; do
			echo "[ ${LS_Dir}/.rhosts File ]"
			if [ -f ${LS_Dir}/.rhosts ]; then
				LI_FileExist=1

				if [ `cat ${LS_Dir}/.rhosts | awk -F'#' '{print $1}' | grep '\+' | wc -l` -gt 0 ]; then
					cat ${LS_Dir}/.rhosts | awk -F'#' '{print $1}' | grep '\+'
					LB_BadCase=1
				else
					echo "\+ OPTION NOT FOUND"
				fi
			else
				echo "${LS_Dir}/.rhosts NOT FOUND"
				echo ""
			fi
		done

		if [ ${LI_FileExist} -eq 0 ]; then
			LB_GoodCase=1
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LB_GoodCase}" -gt 0 ]; then
			echo "[양호] hosts.equiv 파일과 rhosts 파일이 존재하지 않음"
			RESULT="GOOD"		
		else
			echo "[양호] hosts.equiv 파일 또는 rhosts 파일이 존재하지만 모든 호스트를 허용하지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	
	} > $STATUS_FILE
}


Unix_026() {
	{
		echo "양호: 원격 터미널 서비스를 사용하지 않거나, 사용 시 root 직접 접속을 차단한 경우" 
		echo "취약: 원격 터미널 서비스 사용 시 root 직접 접속을 허용한 경우" 
	} > $STANDARD_FILE
	
	{
		LI_FileExist=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_GoodCase=0
		LI_Count=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "sshd" 
		if [ ${PCK} -eq 1 ]; then
			echo "[ SSH Service Port ]"
			if [ `netstat -an | grep ':22 ' | wc -l` -eq 0 ]; then
				echo "SSH Default Port Number(22) is changed"
			else
				netstat -an | grep ':22 '
			fi
			
			for FILE in ${GS_SSHDConf}; do
				if [ -f ${FILE} ]; then
					LI_FileExist=1
					echo ""
					echo "[ sshd config (${FILE}) ]"
					if [ `cat ${FILE} | awk -F"#" '{print $1}' | grep 'PermitRootLogin' | grep -i 'no' | wc -l` -eq 0 ]; then
						if [ `cat ${FILE} | awk -F"#" '{print $1}' | grep 'PermitRootLogin' | wc -l` -gt 0 ]; then
							cat ${FILE} | awk -F"#" '{print $1}' | grep 'PermitRootLogin'
							echo ""
						else
							#echo "OPTION NOT FOUND"
							cat ${FILE} | grep 'PermitRootLogin'							
							echo ""
						fi
						LB_BadCase=1
					else
						cat ${FILE} | awk -F"#" '{print $1}' | grep 'PermitRootLogin'
						echo ""
					fi
				fi
			done
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sshd ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sshd ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sshd ]"
			echo "ssh SERVICE NOT ACTIVATE"
			echo ""
			LI_Count=`expr "${LI_Count}" + "1"`
		fi
		
		if [ ${LI_FileExist} -eq 0 -a ${PCK} -gt 0 ]; then
			echo "[ Config File : "`echo ${GS_SSHDConf} | tr " " ", "`" ]"
			echo "ssh config FILE NOT FOUND"
			echo ""
			LB_CheckCase1=1
		else
			LI_FileExist=0
		fi
		
		PROCESS_CHECKER "telnet" "telnet.socket"
		if [ ${PCK} -eq 1 ]; then
			echo "[ Telnet Service Port ]"
			if [ `netstat -an | grep ':23 ' | wc -l` -eq 0 ]; then
				echo "Telnet Default Port Number(23) is changed"
			else
				netstat -an | grep ':23 '
			fi
			
			echo ""

			if [ -f ${SECURETTY} ]; then
				echo "[ ${SECURETTY} ]"
				cat ${SECURETTY}
				LI_FileExist=1
				if [ `cat ${SECURETTY} | awk -F"#" '{print $1}' | grep -i 'pts\/' | wc -l` -gt 0 ]; then
					LB_BadCase=1
				fi
					
			else
				echo "${SECURETTY} config FILE NOT FOUND"
				echo ""
				LB_BadCase=1
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ Telnet ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ Telnet ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ Telnet ]"
			echo "Telnet SERVICE NOT ACTIVATE"
			echo ""
			LI_Count=`expr "${LI_Count}" + "1"`
		fi
		
		if [ ${LI_Count} -eq 2 ]; then
			LB_GoodCase=1
		fi
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] 설정 파일이 존재하지 않아 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ "${LB_GoodCase}" -eq 1 ]; then
			echo "[양호] 원격 접속 서비스가 구동중이지 않음"
			RESULT="GOOD" 
		else
			echo "[양호] root계정의 원격 접속이 비활성화 되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}



Unix_027() {
	{
		echo "양호: 접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정한 경우" 
		echo "취약: 접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정하지 않은 경우" 
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		 
		
		echo "[ ${GS_HostsDeny} ]"
		if [ -f ${GS_HostsDeny} ]; then
			if [ `cat ${GS_HostsDeny} | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w` -eq 0 ]; then
				echo "/etc/hosts.deny FILE CONTENTS EMPTY"
			else
				cat ${GS_HostsDeny} | awk -F"#" '{print $1}' | sed '/^$/d'
			fi
		else
			echo "FILE NOT FOUND"
		fi
		echo ""
		
		echo "[ ${GS_HostsAllow} ]"
		if [ -f ${GS_HostsAllow} ]; then
			if [ `cat ${GS_HostsAllow} | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w` -eq 0 ]; then
				echo "/etc/hosts.allow FILE CONTENTS EMPTY"
			else
				cat ${GS_HostsAllow} | awk -F"#" '{print $1}' | sed '/^$/d'
			fi
		else
			echo "FILE NOT FOUND"
		fi
		echo ""
		
	
		echo "[ iptables -L ]"
		if [ `iptables -L | wc -l` -ge 1 ]; then 
			iptables -L
		else
			echo "iptables list NOT FOUND"
		fi
		echo "-------------------------------------------------------------------"
		echo "[확인] 시스템 서비스의 접근통제(방화벽, tcp-wrapper, 3rd-party 제품 등을 활용)가 적절하게 수행되고 있는지 수동 점검 및 담당자와의 인터뷰가 필요"
		RESULT="CHECK"
		echo "-------------------------------------------------------------------"		
	} > $STATUS_FILE
}

Unix_028(){
	{
		echo "양호: 세션 타임아웃 값이 900초 이하(15분)로 설정 되어 있을 경우"
		echo "취약: 아래 내용 중 해당사항이 있는 경우"
		echo "	1) 내부 규정에 세션 종료 시간이 명시되어 있을 경우 : 세션 타임아웃이 내부 규정에 명시된 세션 종료 시간보다 초과로 설정된 경우"
		echo "	2) 내부 규정에 세션 종료시간이 명시되어 있지 않을 경우 : 세션 타임아웃 값이 900초 이하(15분)로 설정 되어 있지 않을 경우"
	} > $STANDARD_FILE
	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_GoodCase=0
		LB_BadCase=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"
		echo "[ USING SHELL ]"
		echo "${SHELL}"
		echo ""
		if [ `echo "${SHELL}" | grep -i bin/sh | wc -l` -gt 0 -o  `echo ${SHELL} | grep -i ksh | wc -l` -gt 0 -o `echo ${SHELL} | grep -i bash | wc -l` -gt 0 ]; then 
			for LS_File in ${GS_ProfileConf}; do
				echo "[ ${LS_File} file ]"
				if [ -e ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i "TMOUT" | grep -i "=" | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i "TMOUT"
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i "export" | grep -i "TMOUT" | wc -l` -eq 0 ]; then
							echo "export TMOUT NOT FOUND!"
							LB_BadCase=1
						elif [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'TMOUT' | awk -F"=" '{if ($2 > 0 && $2 <= 900) print $2}' | wc -l` -eq 0 ]; then
							LB_CheckCase1=1
						fi
					else
						echo "TMOUT OPTION NOT FOUND"
						LB_BadCase=1
					fi
				else
					echo "${LS_File} FILE NOT FOUND"
					LB_CheckCase2=1
				fi
				echo ""
				break
			done
		elif [ `echo "${SHELL}" | grep -i "csh\|tcsh" | wc -l ` -gt 0 ]; then
			for LS_File in ${GS_CshConf}; do
				echo "[ ${LS_File} file ]"
				if [ -e ${LS_File} ]; then	
					LI_FileExist=1
					if [ `cat "${LS_File}" | awk -F"#" '{print $1}' | grep -i "set autologout" | wc -l` -gt 0 ]; then
						cat "${LS_File}" | grep -i "set autologout"
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'set autologout' | awk -F"=" '{if ($2 > 0 && $2 <= 15) print $2}' | wc -l` -eq 1 ]; then
                        	LB_GoodCase=1
                    	fi
					else
						echo "autologout OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
				echo ""
			done
			if [ "${LI_FileExist}" -eq 0 ]; then
				LB_CheckCase2=1
			fi
			if [ "${LB_GoodCase}" -eq 0 -a "${LB_BadCase}" -eq 0 ]; then
				LB_CheckCase1=1
			fi
		else
			echo "Shell : ${SHELL}"
			LB_CheckCase2=1
		fi
		echo ""
		echo "-------------------------------------------------------------------"
		if [ "${LB_CheckCase1}" -eq 1 ]; then
			echo "[확인] 세션 타임아웃이 내부 규정에 맞게 설정되어 있는지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ "${LB_CheckCase2}" -eq 1 ]; then
			echo "[확인] csh, bash, sh, ksh가 아닌 다른 쉘을 사용하거나 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ "${LB_BadCase}" -eq 1 ]; then
                        echo "[취약] 세션 타임아웃 값이 설정되어 있지 않음"
                        RESULT="BAD"
		else
			echo "[양호] 세션 타임아웃 값이 양호하게 설정되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_034() {
	{
		echo "양호: 아래의 항목 중 해당 사항이 없는 경우" 
		echo "- 불필요한 automountd 서비스가 불필요하게 활성화된 경우"
		echo "취약: 아래의 항목 중 해당하는 조건이 있는 경우" 
		echo "- 취약한 버전의 automountd 서비스가 불필요하게 활성화된 경우"
	} > $STANDARD_FILE
		
	{
		#LS_UnnecessaryServices="autofs automount"
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0

		echo "-------------------------------------------------------------------"
		#for LS_Service in ${LS_UnnecessaryServices}; do
		PROCESS_CHECKER "automount" ""
		INETDON=0
		
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ automount ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ automount ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ automount ]"
			echo "automount SERVICE NOT ACTIVATE"
			echo ""
		fi
		
		PROCESS_CHECKER "" "autofs"
		
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ autofs ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ autofs ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		fi
		#done

		INETDON=1

		echo "-------------------------------------------------------------------"

		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] 사용중인 서비스들이 불필요한 서비스인지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
		else
			echo "[양호] 불필요한 서비스가 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_035(){
	{ 
		echo "양호: 아래의 항목 중 해당 사항이 없는 경우" 
		echo "   1. tftp, talk, ntalk 서비스가 불필요하게 활성화된 경우" 
		echo "   2. finger 서비스 활성화" 
		echo "   3. rexec, rlogin, rsh 서비스 활성화" 
		echo "   4. DoS 공격에 취약한 echo, discard, daytime, chargen 서비스 활성화" 
		echo "   5. NIS, NIS+ 서비스 활성화" 
		echo "취약: 서비스 활성화 여부가 양호조건에 부합하지 않는 경우" 
		
	}  > $STANDARD_FILE
   
	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LS_WeakServices="tftp talk ntalk finger rexec rlogin rsh echo daytime discard chargen"
		# nis 일 경우 administrator도 검색되는 문제로 인해 로직 따로 구성

		echo "-------------------------------------------------------------------"
		for LS_Service in ${LS_WeakServices}; do
			PROCESS_CHECKER ${LS_Service}
			INETDON=0
			if [ ${PCK} -eq 1 ]; then
				if [ `echo ${LS_Service} | grep "tftp" | wc -l` -gt 0 -o `echo ${LS_Service} | grep "talk" | wc -l` -gt 0 -o `echo ${LS_Service} | grep "ntalk" | wc -l` -gt 0 ]; then
				LB_CheckCase1=1
			else
				LB_BadCase=1
			fi
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} SERVICE NOT ACTIVATE"
				echo ""
			fi
		done
	  
		echo "<< NIS Services >>"
		if [ `ps -ef | grep -v 'grep' | grep -v 'administrators' | grep -i 'NIS' | wc -l` -gt 0 ]; then
			echo "[NIS process check]"
			ps -ef | grep -v 'grep' | grep -v 'administrators' | grep -i 'NIS'
			LB_BadCase=1
			echo " "
		fi
	  
		if [ `ps -ef inetd | grep -v 'grep' | wc -l` -gt 0 ]; then	
			if [ -f /etc/inetd.conf ]; then
				if [ `cat /etc/inetd.conf | awk -F"#" '{print $1}' | grep -v 'administrators' | grep -i 'NIS' | wc -l` -gt 0 ]; then
					echo "[NIS config check]"
					cat /etc/inetd.conf | awk -F"#" '{print $1}' | grep -v 'administrators' | grep -i 'NIS'
					LB_BadCase=1
					echo " "
				fi
			else
				LB_CheckCase2=1
				echo "[ NIS config check ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			fi
		fi

		if [ `rpcinfo -p | grep -v 'administrators' | grep -i 'NIS' | wc -l` -gt 0 ]; then
			echo "[NIS rpcinfo -p command check]"
			rpcinfo -p | grep -v 'administrators' | grep -i 'NIS' | wc -l
			LB_BadCase=1
			echo " "
		fi
		
		if [ `ps -ef | grep -i xinetd |grep -v 'grep' | wc -l` -gt 0 ]; then
			if [ -f /etc/xinetd.conf ]; then
				XINETD_CONFGCK=1
				if [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "disabled" | grep "NIS" | wc -l` -gt 0 ]; then
					GA_NULL="0"
					#   echo "disabled 설정에 체크할 서비스가 존재해서 실행되지 않음"
				elif [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "enabled" | grep "NIS" | wc -l` -gt 0 ]; then
					if [ `echo ${GS_TotalXinetdServices} | grep -i "${PROCESS_NAME}" | wc -l` -gt 0 ]; then
					#   	echo "enabled에 체크할 서비스가 존재하고 상세 설정도 존재함"
						PCK=1
						echo "[ NIS ]"
						echo "NIS service activate with xinetd"
						echo ""
						#   else
						#   	echo "enabled에 체크할 프로세스가 존재하지만 상세 설정이 존재하지 않음"
					fi
				elif [ `cat ${GS_XinetdConfingFile} | awk -F"#" '{print $1}' | grep "enabled" | awk -F"=" '{print $2}' | wc -l` -gt 0 ]; then
					GA_Null="0"
					#   echo "enabled은 활성화되어 있지만 체크할 프로세스가 존재하지 않음"
				elif [ `echo "${GS_ActiveXinetdServices}" | grep -i "NIS" | grep -vi "administrator" | wc -l` -gt 0 ]; then
					#   echo "활성화된 서비스 중 체크할 프로세스가 존재함"
					PCK=1
					echo "[ NIS ]"
					echo "NIS service activate with xinetd"
					echo ""
					#else
					#   echo "프로세스 실행 안함"
				fi
			else
				echo "XINETD_CONF NOT FOUND!"
				XINETD_CONFGCK=2
			fi
		fi

		for LS_Service in ${GS_NISServices}; do
			PROCESS_CHECKER ${LS_Service}
			if [ ${PCK} -eq 1 ]; then
				LB_BadCase=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} config check ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} config check ]"
				echo "${LS_Service}  SERVICE NOT ACTIVATE"
				echo ""
			fi
		done
	  
		INETDON=1

		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] tftp, talk, ntalk 구동 중, 불필요한 서비스인지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] 취약한 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
   } > $STATUS_FILE 2> /dev/null
}

Unix_037(){
	{
		echo "양호: 암호화되지 않은 FTP 서비스가 비활성화된 경우"
		echo "취약: 암호화되지 않은 FTP 서비스가 활성화된 경우" 
	} > $STANDARD_FILE

	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0

		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER "ftp"
		
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp SERVICE NOT ACTIVATE"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] FTP 서비스가 구동 중, 업무상 필요한지 여부 담당자와의 인터뷰 필요(SFTP일 경우 양호)"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
        	echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         	RESULT="CHECK"
		else
			echo "[양호] FTP 서비스가 사용중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_040() {
	{
		echo "양호: 디렉터리 검색 기능을 사용하지 않는 경우"
		echo "취약: 디렉터리 검색 기능을 사용하는 경우"	
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_042() {
	{
		echo "양호: 상위 디렉토리에 이동제한을 설정한 경우"  
		echo "취약: 상위 디렉토리에 이동제한을 설정하지 않은 경우"
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_043() {
	{
		echo "양호: 기본으로 생성되는 불필요한 파일 및 디렉터리가 제거되어 있는 경우"
		echo "취약: 기본으로 생성되는 불필요한 파일 및 디렉터리가 제거되지 않은 경우"	
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_044() {
	{
		echo "양호: 파일 업로드 및 다운로드를 제한한 경우" 
		echo "취약: 파일 업로드 및 다운로드를 제한하지 않은 경우"
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
		
	} > $STATUS_FILE
}

Unix_045() {
	{
		echo "양호: Apache 데몬이 root 권한으로 구동되지 않는 경우" 
		echo "취약: Apache 데몬이 root 권한으로 구동되는 경우"
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_046() {
	{
		echo "양호: DocumentRoot를 별도의 디렉터리로 지정한 경우" 
		echo "취약: DocumentRoot를 기본 디렉터리로 지정한 경우"
	} > $STANDARD_FILE
		
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_047() {
	{
		echo "양호: 심볼릭 링크, aliases 사용을 제한한 경우" 
		echo "취약: 심볼릭 링크, aliases 사용을 제한하지 않은 경우"
	} > $STANDARD_FILE
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_048(){
   {
      echo "양호: 웹 서비스가 실행되고 있지 않은 경우"
      echo "취약: 웹 서비스가 불필요하게 실행 중인 경우"
   } > $STANDARD_FILE
      
   {
    	LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		apache_inactive=0
		LB_WebServices="wsm jeus tomcat apache2 httpd"
		echo "-------------------------------------------------------------------"
		for LS_Service in ${LB_WebServices}; do
			# 우분투의경우 프로세스에서 apache2로 돌고있어 로직 추가
			if [ "$LS_Service" = "apache2" ]; then
				PROCESS_CHECKER ${LS_Service}
				if [ ${PCK} -eq 1 ]; then
					LB_CheckCase1=1
					continue  # apache2 활성화인 경우 httpd 체크하지 않음
				else
					apache_inactive=1
				fi
			elif [ "$LS_Service" = "httpd" ]; then
				if [ ${apache_inactive} -eq 1 ]; then
					# apache2 비활성화인 경우 httpd를 체크
					PROCESS_CHECKER ${LS_Service}
					if [ ${PCK} -eq 1 ]; then
						LB_CheckCase1=1
					else
						# apache2, httpd 모두 비활성화 상태
						echo "[ httpd or apache2 process check ]"
						echo "httpd, apache2 SERVICES NOT ACTIVE"
						echo ""
					fi
					break
				fi
			else
				PROCESS_CHECKER ${LS_Service}
				INETDON=0
				if [ ${PCK} -eq 1 ]; then
					LB_CheckCase1=1
				elif [ ${INETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase2=1
					echo "[ ${LS_Service} ]"
					echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
					echo ""
				elif [ ${XINETD_CONFGCK} -eq 2 ]; then
					LB_CheckCase3=1
					echo "[ ${LS_Service} process check ]"
					echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
					echo ""
				else
					echo "[ ${LS_Service} process check ]"
					echo "${LS_Service} SERVICE NOT ACTIVATE"
					echo ""
				fi
			fi
		done

		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] 웹 서비스가 구동 중, 업무상 필요한지 여부 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] 불필요한 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
   } > $STATUS_FILE
}

Unix_060() {
	{
		echo "양호: 기본 관리자 계정명을 사용하고 있지 않은 경우" 
		echo "취약: 기본 관리자 계정명을 사용하고 있는 경우" 
	} > $STANDARD_FILE
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인 후 기본 관리자 계정명을 사용하고 있는지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인 후 기본 관리자 계정명을 사용하고 있는지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
			RESULT="CHECK"
		else
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"	
	} > $STATUS_FILE
}

Unix_062() {
	{
		echo "양호: DNS 서비스를 사용하지 않거나 DNS 서비스 버전 정보가 노출되고 있지 않은 경우" 
		echo "취약: DNS 서비스를 사용하고 있으며 DNS 서비스 버전 정보가 노출되고 있는 경우" 
	} > $STANDARD_FILE
		
	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_GoodCase=0
		LI_FileExist=0
		# Bind 4.x : 개발 중단
		# Bind 8.x : root DNS 및 대부분의 DNS에서 사용, 일반적인 Query 응답률 가장 좋음,
		# Bind 9.x : DNSSEC 등 보안을 고려한 Code-rewrite 기능 개선 및 multithread 지원
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "named"
		INETDON=0
		if [ ${PCK} -eq 1 ]; then
			for LS_File in ${GS_DNSConf}; do
				if [ -f ${LS_File} ]; then
					echo "[ ${LS_File} ]"
					LI_FileExist=1
					
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'version' | wc -l` -gt 0 ]; then #버전이 존재함
						cat ${LS_File} | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'version'
						echo ""
		                if [ ` cat ${LS_File} | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'version' | awk '{print $2}' | grep [4-9] | wc -l` -gt 0 ]; then # 버전 정보가 노출됨
		                    LB_BadCase=1
		                fi
		            else
		            	LB_BadCase=1
		                echo "version OPTION NOT FOUND"
		                echo ""
		            fi
				fi
			done
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo " named SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=1
		fi

		if [ ${LI_FileExist} -eq 0 ]; then
			echo "named config FILE NOT FOUND" 
			LB_CheckCase1=2
		fi
		INETDON=1
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD" 
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] DNS 서비스가 구동중이지만 설정파일을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_GoodCase} -eq 1 ]; then
	        echo "[양호] DNS 서비스가 구동중이지 않음" 
			RESULT="GOOD" 
		else
			echo "[양호] DNS 서비스의 버전정보가 노출되지 않음" 
			RESULT="GOOD" 
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_063() {
	{
		echo "양호: Recurisve query를 금지하고 있거나, 신뢰된 호스트만 허용하는 경우" 
		echo "취약: Recurisve query를 접근 통제 없이 허용하고 있는 경우" 
	} > $STANDARD_FILE
		
	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_GoodCase=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "named"
		INETDON=0
		if [ ${PCK} -eq 1 ]; then
			if [ -f "/etc/named.conf" ]; then
				echo "[ /etc/named.conf ]"
				if [ `cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'recursion' | wc -l` -gt 0 ]; then #recursion 존재함
					cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'recursion'
					echo ""
	                if [ ` cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'recursion' | awk '{print $2}' | grep "yes" | wc -l` -gt 0 ]; then 
	                	if [ `cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'allow-recursion' | wc -l` -gt 0 ]; then
	                    	if [ `cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'allow-recursion' | grep -i "any" | wc -l` -gt 0 ]; then
	                    		LB_BadCase=1
	                 	   	fi
	                    else
	                    	LB_BadCase=1
	                	fi
	                fi
	            else
	                echo "Option NOT FOUND"
	                echo ""
	                LB_BadCase=1
	            fi					
			else
				echo "/etc/named.conf FILE NOT FOUND"
				LB_CheckCase1=1
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo " named SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=1
		fi

		INETDON=1

		echo "-------------------------------------------------------------------"	
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD" 
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] DNS 서비스가 구동중이지만 설정파일을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_GoodCase} -eq 1 ]; then
	        echo "[양호] DNS 서비스가 구동중이지 않음" 
			RESULT="GOOD" 
		else
			echo "[양호] DNS 서비스의 Recursive 제한 설정이 되어 있음" 
			RESULT="GOOD" 
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_064(){
	{
		echo "양호: 알려진 취약점이 없는 DNS 버전을 사용하는 경우"
		echo "취약: 패치관리에 대한 금융회사의 내부규정을 준수하지 않을 경우, 단 금융회사 내부규정에 명시되지 않은 경우 통상 1개월 이내 최신 버전으로 패치 적용할 것을 권고"
	} > $STANDARD_FILE

	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "named"
	   
		if [ ${PCK} -eq 1 ]; then
			echo "[ DNS Version ]"
			named -v
			#LS_MainVersion=`named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $1}'`
			#LS_SubVersion=`named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $2}'`
			#LS_BuildVersion = `echo $LS_Version | awk -F"." '{print $3}'`
			#CVE가 나온것과 관련 없이 EOL은 무조건 취약이며, DNS 버전 관리를 하고 있으면 양호
			if [ `named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $1}'` -gt 8 ]; then
				if [ `named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $2}'` -eq 11 ]; then
					LB_BadCase=1
				elif [ `named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $2}'` -eq 16 ]; then
					LB_BadCase=1
				elif [ `named -v | awk '{print $2}' | awk -F"-" '{print $1}' | awk -F"." '{print $2}'` -gt 17 ]; then
					LB_CheckCase1=1
				else
					echo "Using EOL(End of Life) version"
					LB_BadCase=1
				fi
			else
				echo "Using EOL(End of Life) version"
				LB_BadCase=1
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo "DNS SERVICE NOT ACTIVATE"
			echo ""
		fi
			echo ""
			echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
		   echo "[취약]"
		   RESULT="BAD" 
		elif [ ${LB_CheckCase1} -eq 1 ]; then
		   echo "[확인] 내부 규정에 의해 DNS 버전관리를 진행하고 있는지 담당자와의 인터뷰 필요(증적 필요)"
		   RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
		   echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		   RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
		   echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		   RESULT="CHECK"
		else
		   echo "[양호] DNS 서비스가 구동중이지 않음" 
		   RESULT="GOOD" 
		fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_066(){
	{
		echo "양호: DNS 서비스 미사용 또는 Zone Transfer를 허가된 사용자에게만 허용한 경우"
		echo "취약: DNS 서비스를 사용하며 Zone Transfer를 모든 사용자에게 허용한 경우"	
	} > $STANDARD_FILE

	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_GoodCase=0
		echo "-------------------------------------------------------------------"
		

		PROCESS_CHECKER "named"
		INETDON=0
		if [ ${PCK} -eq 1 ]; then
			if [ -f "/etc/named.conf" ]; then
				echo "[ /etc/named.conf ]"
            	if [ `cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'allow-transfer' | wc -l` -gt 0 ]; then
            		cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'allow-transfer'
					echo ""
                	if [ `cat "/etc/named.conf" | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'allow-transfer' | grep -i "any" | wc -l` -gt 0 ]; then
                		LB_BadCase=1
             	   	fi
                else
                	echo "OPTION NOT FOUND"
                	echo ""
                	LB_BadCase=1
            	fi				
			else
				echo "/etc/named.conf FILE NOT FOUND"
				LB_CheckCase1=1
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo " named SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=1
		fi

		INETDON=1

		echo "-------------------------------------------------------------------"	
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD" 
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] DNS 서비스가 구동중이지만 설정파일을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
	    elif [ ${LB_GoodCase} -eq 1 ]; then
	        echo "[양호] DNS 서비스가 구동중이지 않음" 
			RESULT="GOOD"
		else
			echo "[양호] BIND 서비스의 Zone Transfer 제한 설정이 되어 있음" 
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_069(){
	{
		echo "양호: 비밀번호 관리 정책이 설정된 경우 (최소 8자, 영문/숫자/특수문자, 최대 90일, 최소 1일)"
		echo "취약: 비밀번호 관리 정책이 설정되지 않은 경우"
	} > $STANDARD_FILE

	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase=0
		echo "-----------------------------------------------------------------"  
		#Debian
		if [ -f "/etc/pam.d/common-password" ]; then 
			echo "[ /etc/pam.d/common-password ]"
			LI_Minlen=0
			LI_Minlen1=0
			LI_Minlen2=0
			LI_Complexity=0
			LI_FileExist=1
			LI_CharCredit=0
			LA_Tmp=0
			#cracklib.so 모듈이 존재할 경우
			if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | wc -l` -gt 0 ]; then
				cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so"
				echo ""
				#enforce_for_root 옵션 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -i enforce_for_root | wc -l` -eq 0 ]; then
					LB_BadCase=1
				fi
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "minlen=[0-9]*" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
					LI_Minlen=`cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "minlen=*[0-9]*" | awk -F"=" '{print $2}'`
				else
					#minlen이 존재하지 않을 경우 기본값 8
					LI_Minlen=9
				fi
				#ucredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ucredit=\-[0-9]*" | wc -l` -gt 0 ]; then
					LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ucredit=0" | wc -l` -gt 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				fi
				#lcredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "lcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "lcredit=0" | wc -l` -gt 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				fi
				#ucredit, lcredit 둘 중 하나 사용 확인
				if [ "${LI_CharCredit}" -gt 0 ]; then
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
					if [ "${LI_CharCredit}" -eq 2 ]; then
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi
				fi
				#dcredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "dcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "dcredit=0" | wc -l` -gt 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				fi
				#ocredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "ocredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ocredit=0" | wc -l` -gt 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				fi
				#패스워드 복잡도 확인
				if [ "${LI_Complexity}" -ge 3 -a "${LA_Tmp}" -eq 1 ]; then
					if [ "${LI_Minlen}" -ge 8 ]; then
						LB_GoodCase=1
					fi
				elif [ "${LI_Complexity}" -ge 2 -a "${LA_Tmp}" -eq 2 ]; then
					if [ "${LI_Minlen}" -ge 10 ]; then
						LB_GoodCase=1
					fi
				fi			
			else
				echo "pam_cracklib.so OPTION NOT FOUND"
				echo ""
			fi
			
			LI_Minlen=0
			LI_Ucredit=0
			LI_Lcredit=0
			LI_Dcredit=0
			LI_Ocredit=0
			LI_CharCredit=0
			LI_Complexity=0
			LA_Tmp=0
			system_uc=0
			system_lc=0
			system_dc=0
			system_oc=0
			pwquality_uc=0
			pwquality_lc=0
			pwquality_dc=0
			pwquality_oc=0
			#pwquality.so 모듈 사용할 경우
			if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | wc -l` -gt 0 ]; then
				cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so"
				#enforce_for_root 옵션 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -i enforce_for_root | wc -l` -eq 0 -a `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep -i enforce_for_root | wc -l` -eq 0 ]; then
					LB_BadCase=1
				fi
				#minlen값 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "minlen=[0-9]*" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
					LI_Minlen=`cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "minlen=*[0-9]*" | awk -F"=" '{print $2}'`	
				fi
				#ucredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ucredit=\-[0-9]*" | wc -l` -gt 0 ]; then
					system_uc=1
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ucredit=0" | wc -l` -gt 0 ]; then
					system_uc=0
				fi
				#lcredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "lcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					system_lc=1
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "lcredit=0" | wc -l` -gt 0 ]; then
					system_lc=0
				fi
				#dcredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "dcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					system_dc=1
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "dcredit=0" | wc -l` -gt 0 ]; then
					system_dc=0
				fi
				#ocredit 확인
				if [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "ocredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
					system_oc=1
				elif [ `cat "/etc/pam.d/common-password" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ocredit=0" | wc -l` -gt 0 ]; then
					system_oc=0
				fi

				
				# pwquality.conf 파일 확인
				if [ -f "/etc/security/pwquality.conf" ]; then
					echo "[ /etc/security/pwquality.conf ]" 
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w` -eq 0 ]; then
						echo "OPTION NOT FOUND"
						echo ""
					else 
						cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | sed '/^$/d'
						echo ""
					fi
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "minlen" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
						if [ "${LI_Minlen}" -eq 0 ]; then
							LI_Minlen=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "minlen" | awk -F"=" '{print $2}'`
						fi
					else
						if [ "${LI_Minlen}" -eq 0 ]; then
							LI_Minlen=8
						fi
					fi
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ucredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Ucredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ucredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Ucredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_uc=1
						elif [ "${LI_Ucredit}" -eq 0 ]; then
							pwquality_uc=0
						fi
					fi

					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "lcredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Lcredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "lcredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Lcredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_lc=1
						elif [ "${LI_Lcredit}" -eq 0 ]; then
							pwquality_lc=0
						fi
						
					fi

					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "dcredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Dcredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "dcredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Dcredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_dc=1
						elif [ "${LI_Dcredit}" -eq 0 ]; then
							pwquality_dc=0
						fi
						
					fi
					
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ocredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Ocredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ocredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Ocredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_oc=1
						elif [ "${LI_Ocredit}" -eq 0 ]; then
							pwquality_oc=0
						fi
						
					fi
				else
					echo "[ /etc/security/pwquality.conf ]" 
					echo "FILE NOT FOUND"
					echo ""
				fi
				
				#ucredit
				if [ "${system_uc}" -eq 0 -a "${pwquality_uc}" -eq 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				else
					LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
				fi
				#lcredit
				if [ "${system_lc}" -eq 0 -a "${pwquality_lc}" -eq 0 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				else
					LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
				fi
				#ucredit, lcredit 비교
				if [ "${LI_CharCredit}" -gt 0 ]; then
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
					if [ "${LI_CharCredit}" -eq 2 ]; then
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi
				fi
				#dcredit
				if [ "${system_dc}" -eq 1 -a "${pwquality_dc}" -eq 1 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				else
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
				fi
				#ocredit
				if [ "${system_oc}" -eq 1 -a "${pwquality_oc}" -eq 1 ]; then
					LA_Tmp=`expr "${LA_Tmp}" + "1"`
				else
					LI_Complexity=`expr "${LI_Complexity}" + "1"`
				fi
				
				#패스워드 복잡도 판별
				if [ "${LI_Complexity}" -ge 3 -a "${LA_Tmp}" -eq 1 ]; then
					if [ "${LI_Minlen}" -ge 8 ]; then
						LB_GoodCase=1
					fi
				elif [ "${LI_Complexity}" -ge 2 -a "${LA_Tmp}" -eq 2 ]; then
					if [ "${LI_Minlen}" -ge 10 ]; then
						LB_GoodCase=1
					fi
				fi
			else
				echo "pam_pwquality.so NOT FOUND"
				echo ""
			fi
		#RHEL일 경우	
		else
			if [ -f "/etc/pam.d/system-auth" ]; then
				echo "[ /etc/pam.d/system-auth ]"
				LI_Minlen=0
				LI_Complexity=0
				LI_FileExist=1
				LI_CharCredit=0
				LA_Tmp=0
				version=$(
					(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null || \
					grep -oP '\d+(?=\.)' /etc/os-release 2>/dev/null) || \
					grep -oP '\d+' /etc/redhat-release 2>/dev/null | head -n 1 || \
					awk '{print $NF}' /etc/redhat-release 2>/dev/null | awk -F"." '{print $1}')
				#rhel5,6버전에서는 pam_cracklib.so 모듈에 enforce_for_root 옵션이 존재하지 않으므로 cracklib사용 시 취약
				if [ $version -eq 5 -o $version -eq 6 ]; then
					#password-auth, system-auth파일에서 pam_cracklib.so 모듈로 패스워드 복잡도 설정 시 취약 
					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "minlen\|ocredit\|dcredit\|ucredit\|lcredit" | wc -l` -gt 0 -a `cat "/etc/pam.d/password-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "minlen\|ocredit\|dcredit\|ucredit\|lcredit" | wc -l` -gt 0 ]; then
						cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so"
						LB_BadCase=1
					#cracklib.so 모듈이 존재하지 않을 경우 passwdqc.so 모듈 확인
					else
						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_passwdqc.so" | wc -l` -gt 0 ]; then
							cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_passwdqc.so"
							OPTION_VALUE=`cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_passwdqc.so" | awk -F"min=" '{print $2}' | awk -F'"' '{print $1}' | awk -F"," '{print $1 " " $2 " " $3 " " $4 " " $5}'`
							CNT=0
							# 각 모듈의 자리가 복잡도를 만족하는지 확인
							for OPTION in ${OPTION_VALUE}; do
								case ${CNT} in 
									0)
										if [ ${OPTION} != "disabled" ]; then
											LB_BadCase=1
										else
											LB_GoodCase=1
										fi;;
									1)
										if [ ${OPTION} != "disabled" ]; then
											LB_BadCase=1
										else
											LB_GoodCase=1
										fi;;
									2)
										;;
									3)
										if [ `echo ${OPTION} | grep "[0-9]" | sed '/^$/d' | wc -l` -gt 0 ]; then
											if [ ${OPTION} -lt 8 ]; then
												LB_BadCase=1
											else
												LB_GoodCase=1
											fi
										elif [ ${OPTION} == "disabled" ]; then
											N3=1 
										fi;;
									4)
										if [ `echo ${OPTION} | grep "[0-9]" | sed '/^$/d' | wc -l` -gt 0 ]; then
											if [ ${OPTION} -lt 8 ]; then
												LB_BadCase=1
											else
												LB_GoodCase=1
											fi
										elif  [ ${OPTION} == "disabled" ]; then
											N4=1
										fi;;
								esac
								CNT=$(($CNT+1)) 
							done

							if [ "${N4}" -eq 1 ]; then
								if [ "${N3}" -eq 1 ];then
									LB_BadCase=1
								else
									LB_GoodCase=1
								fi
							else
								LB_GoodCase=1
							fi
						else
							echo "pam_passwdqc.so OPTION NOT FOUND"
							echo ""
							LB_BadCase=1
						fi
					fi
				#rhel 5,6버전이 아닐 경우
				else
					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | wc -l` -gt 0 ]; then
						cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so"
						#enforce_for_root 옵션 확인
						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -i enforce_for_root | wc -l` -eq 0 ]; then
							LB_BadCase=1
						fi
						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "minlen=[0-9]*" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
							LI_Minlen=`cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "minlen=*[0-9]*" | awk -F"=" '{print $2}'`
						else
							LI_Minlen=9
						fi
						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ucredit=\-[0-9]*" | wc -l` -gt 0 ]; then
							LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
						elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ucredit=0" | wc -l` -gt 0 ]; then
							LA_Tmp=`expr "${LA_Tmp}" + "1"`
						fi

						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "lcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
							LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
						elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "lcredit=0" | wc -l` -gt 0 ]; then
							LA_Tmp=`expr "${LA_Tmp}" + "1"`
						fi

						if [ "${LI_CharCredit}" -gt 0 ]; then
							LI_Complexity=`expr "${LI_Complexity}" + "1"`
							if [ "${LI_CharCredit}" -eq 2 ]; then
								LA_Tmp=`expr "${LA_Tmp}" + "1"`
							fi
						fi

						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "dcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
							LI_Complexity=`expr "${LI_Complexity}" + "1"`
						elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "dcredit=0" | wc -l` -gt 0 ]; then
							LA_Tmp=`expr "${LA_Tmp}" + "1"`
						fi

						if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep "ocredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
							LI_Complexity=`expr "${LI_Complexity}" + "1"`
						elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_cracklib.so" | grep -o "ocredit=0" | wc -l` -gt 0 ]; then
							LA_Tmp=`expr "${LA_Tmp}" + "1"`
						fi
					else
						echo "pam_cracklib.so OPTION NOT FOUND"
					fi
					echo ""
				fi
			fi

			if [ "${LI_Complexity}" -ge 3 -a "${LA_Tmp}" -eq 1 ]; then
				if [ "${LI_Minlen}" -ge 8 ]; then
					LB_GoodCase=1
				fi
			elif [ "${LI_Complexity}" -ge 2 -a "${LA_Tmp}" -eq 2 ]; then
				if [ "${LI_Minlen}" -ge 10 ]; then
					LB_GoodCase=1
				fi
			fi

			LI_Minlen=0
			LI_Ucredit=0
			LI_Lcredit=0
			LI_Dcredit=0
			LI_Ocredit=0
			LI_CharCredit=0
			LI_Complexity=0
			LA_Tmp=0
			LI_FileExist=1
			#pwquality.so 모듈을 사용할 경우
			if [  `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | wc -l` -gt 0 ]; then
				echo "[ /etc/pam.d/system-auth ]"
				cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so"
				echo ""
				#enforce_for_root 사용 확인
				if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -i enforce_for_root | wc -l` -eq 0 -a `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep -i enforce_for_root | wc -l` -eq 0 ]; then
						LB_BadCase=1
				fi
				if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "minlen\|ocredit\|dcredit\|ucredit\|lcredit" | wc -l` -gt 0 ]; then
					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "minlen=[0-9]*" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
						LI_Minlen=`cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "minlen=*[0-9]*" | awk -F"=" '{print $2}'`
					fi

					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ucredit=\-[0-9]*" | wc -l` -gt 0 ]; then
						system_uc=1
					elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ucredit=0" | wc -l` -gt 0 ]; then
						system_uc=0
					fi

					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "lcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
						system_lc=1
					elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "lcredit=0" | wc -l` -gt 0 ]; then
						system_lc=0
					fi
					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "dcredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
						system_dc=1
					elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "dcredit=0" | wc -l` -gt 0 ]; then
						system_dc=0
					fi

					if [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep "ocredit=\-[0-9]*" | wc -l ` -gt 0 ]; then
						system_oc=1
					elif [ `cat "/etc/pam.d/system-auth" | awk -F"#" '{print $1}' | grep "pam_pwquality.so" | grep -o "ocredit=0" | wc -l` -gt 0 ]; then
						system_oc=0
					fi
				fi
				if [ -f "/etc/security/pwquality.conf" ]; then
					echo "[ /etc/security/pwquality.conf ]" 
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | sed '/^$/d' | wc -w` -eq 0 ]; then
						echo "OPTION NOT FOUND"
						echo ""
					else 
						cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | sed '/^$/d'
						echo ""
					fi
					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "minlen" | awk -F"=" '{print $2}' | wc -w` -gt 0 ]; then
						if [ "${LI_Minlen}" -eq 0 ]; then
							LI_Minlen=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "minlen" | awk -F"=" '{print $2}'`
						fi
					else
						if [ "${LI_Minlen}" -eq 0 ]; then
							LI_Minlen=8
						fi
					fi

					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ucredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Ucredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ucredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Ucredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_uc=1
						elif [ "${LI_Ucredit}" -eq 0 ]; then
							pwquality_uc=0
						fi
					fi

					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "lcredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Lcredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "lcredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Lcredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_lc=1
						elif [ "${LI_Lcredit}" -eq 0 ]; then
							pwquality_lc=0
						fi
						
					fi

					if [ "${LI_CharCredit}" -gt 0 ]; then
						LI_Complexity=`expr "${LI_Complexity}" + "1"`
							if [ "${LI_CharCredit}" -eq 2 ]; then
								LA_Tmp=`expr "${LA_Tmp}" + "1"`
							fi
					fi


					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "dcredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Dcredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "dcredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Dcredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_dc=1
						elif [ "${LI_Dcredit}" -eq 0 ]; then
							pwquality_dc=0
						fi
						
					fi
				

					if [ `cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ocredit" | awk -F"=" '{print $2}' | grep "[0-9]" | wc -l` -gt 0 ]; then
						LI_Ocredit=`cat "/etc/security/pwquality.conf" | awk -F"#" '{print $1}' | grep "ocredit" | awk -F"=" '{print $2}'`
						if [ `echo "${LI_Ocredit}" | grep "\-[1-9]" | wc -l` -gt 0 ]; then
							pwquality_oc=1
						elif [ "${LI_Ocredit}" -eq 0 ]; then
							pwquality_oc=0
						fi
					fi
							

					
					#ucredit
					if [ "${system_uc}" -eq 1 -o "${pwquality_uc}" -eq 1 ]; then
						LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
					else
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi
					#lcredit
					if [ "${system_lc}" -eq 1 -o "${pwquality_lc}" -eq 1 ]; then
						LI_CharCredit=`expr "${LI_CharCredit}" + "1"`
					else
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi
					#ucredit, lcredit 비교
					if [ "${LI_CharCredit}" -gt 0 ]; then
						LI_Complexity=`expr "${LI_Complexity}" + "1"`
						if [ "${LI_CharCredit}" -eq 2 ]; then
							LA_Tmp=`expr "${LA_Tmp}" + "1"`
						fi
					fi
					#dcredit
					if [ "${system_dc}" -eq 1 -o "${pwquality_dc}" -eq 1 ]; then
						LI_Complexity=`expr "${LI_Complexity}" + "1"`
					else
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi
					#ocredit
					if [ "${system_oc}" -eq 1 -o "${pwquality_oc}" -eq 1 ]; then
						LI_Complexity=`expr "${LI_Complexity}" + "1"`
					else
						LA_Tmp=`expr "${LA_Tmp}" + "1"`
					fi

					#복잡도 판별
					if [ "${LI_Complexity}" -ge 3 -a "${LA_Tmp}" -eq 1 ]; then
						if [ "${LI_Minlen}" -ge 8 ]; then
							LB_GoodCase=1
						fi
					elif [ "${LI_Complexity}" -ge 2 -a "${LA_Tmp}" -eq 2 ]; then
						if [ "${LI_Minlen}" -ge 10 ]; then
							LB_GoodCase=1
						fi
					fi
				fi
			else
				echo "pam_pwquality.so OPTION NOT FOUND"
				echo ""
			fi
		fi

		if [ "${LI_FileExist}" -eq 0 ]; then
			echo "패스워드 정책 설정파일을 찾을 수 없음"
			LB_CheckCase=1
		fi

		if [ "${LB_GoodCase}" -eq 0 ]; then
			LB_BadCase=1
		fi

		## 비밀번호 주기 점검 (PASS_MAX_DAYS, PASS_MIN_DAYS, remember)
		echo ""
		echo "[ 비밀번호 주기 및 이력 관리 점검 ]"
		LB_PeriodBad=0

		# PASS_MAX_DAYS 점검 (90일 이하)
		if [ -f "/etc/login.defs" ]; then
			PASS_MAX=`cat "/etc/login.defs" | awk -F"#" '{print $1}' | grep -i "^PASS_MAX_DAYS" | awk '{print $2}' | tail -1`
			PASS_MIN=`cat "/etc/login.defs" | awk -F"#" '{print $1}' | grep -i "^PASS_MIN_DAYS" | awk '{print $2}' | tail -1`
			echo "[ /etc/login.defs ]"
			echo "PASS_MAX_DAYS = ${PASS_MAX:-미설정}"
			echo "PASS_MIN_DAYS = ${PASS_MIN:-미설정}"
			if [ -n "${PASS_MAX}" ] && [ "${PASS_MAX}" -le 90 ] 2>/dev/null && [ "${PASS_MAX}" -gt 0 ] 2>/dev/null; then
				echo "[양호] PASS_MAX_DAYS ${PASS_MAX}일 (90일 이하)"
			else
				echo "[취약] PASS_MAX_DAYS 미설정 또는 90일 초과"
				LB_PeriodBad=1
			fi
			if [ -n "${PASS_MIN}" ] && [ "${PASS_MIN}" -ge 1 ] 2>/dev/null; then
				echo "[양호] PASS_MIN_DAYS ${PASS_MIN}일 (1일 이상)"
			else
				echo "[취약] PASS_MIN_DAYS 미설정 또는 1일 미만"
				LB_PeriodBad=1
			fi
		else
			echo "[ /etc/login.defs ] FILE NOT FOUND"
			LB_PeriodBad=1
		fi
		echo ""

		# remember 점검 (4회 이상)
		LB_RememberFound=0
		# pwhistory.conf 점검 (RHEL 9+)
		if [ -f "/etc/security/pwhistory.conf" ]; then
			REMEMBER_VAL=`cat "/etc/security/pwhistory.conf" | awk -F"#" '{print $1}' | grep -i "remember" | awk -F"=" '{print $2}' | sed 's/ //g' | tail -1`
			echo "[ /etc/security/pwhistory.conf ]"
			echo "remember = ${REMEMBER_VAL:-미설정}"
			if [ -n "${REMEMBER_VAL}" ] && [ "${REMEMBER_VAL}" -ge 4 ] 2>/dev/null; then
				echo "[양호] remember ${REMEMBER_VAL}회 (4회 이상)"
				LB_RememberFound=1
			fi
		fi
		# pam_pwhistory.so 점검 (system-auth 또는 common-password)
		for PAM_FILE in /etc/pam.d/system-auth /etc/pam.d/common-password; do
			if [ -f "${PAM_FILE}" ] && [ ${LB_RememberFound} -eq 0 ]; then
				PAM_REMEMBER=`cat "${PAM_FILE}" | awk -F"#" '{print $1}' | grep "pam_pwhistory.so" | grep -o "remember=[0-9]*" | awk -F"=" '{print $2}'`
				if [ -n "${PAM_REMEMBER}" ]; then
					echo "[ ${PAM_FILE} ]"
					echo "pam_pwhistory.so remember = ${PAM_REMEMBER}"
					if [ "${PAM_REMEMBER}" -ge 4 ] 2>/dev/null; then
						echo "[양호] remember ${PAM_REMEMBER}회 (4회 이상)"
						LB_RememberFound=1
					fi
				fi
			fi
		done
		# pam_unix.so remember 점검
		for PAM_FILE in /etc/pam.d/system-auth /etc/pam.d/common-password; do
			if [ -f "${PAM_FILE}" ] && [ ${LB_RememberFound} -eq 0 ]; then
				UNIX_REMEMBER=`cat "${PAM_FILE}" | awk -F"#" '{print $1}' | grep "pam_unix.so" | grep -o "remember=[0-9]*" | awk -F"=" '{print $2}'`
				if [ -n "${UNIX_REMEMBER}" ]; then
					echo "[ ${PAM_FILE} ]"
					echo "pam_unix.so remember = ${UNIX_REMEMBER}"
					if [ "${UNIX_REMEMBER}" -ge 4 ] 2>/dev/null; then
						echo "[양호] remember ${UNIX_REMEMBER}회 (4회 이상)"
						LB_RememberFound=1
					fi
				fi
			fi
		done
		if [ ${LB_RememberFound} -eq 0 ]; then
			echo "[취약] remember 설정 미발견 (4회 이상 필요)"
			LB_PeriodBad=1
		fi

		if [ ${LB_PeriodBad} -eq 1 ]; then
			LB_BadCase=1
		fi

		echo ""
		echo "-----------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase} -eq 1 ]; then
			echo "[확인] 패스워드 정책 설정 파일을 확인할 수 없어 담당자와 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] 비밀번호 관련 정책들이 올바르게 설정되어 있음"
			RESULT="GOOD"
		fi

		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_070(){
	{	
		echo "양호: 쉐도우 비밀번호를 사용하거나, 비밀번호를 암호화하여 저장하는 경우"
		echo "취약: 쉐도우 비밀번호를 사용하지 않고, 비밀번호를 암호화하여 저장하지 않는 경우"
	} > $STANDARD_FILE
	{
		badCase=0
		fileExist=0
		
		echo "-------------------------------------------------------------------"
		if [ -e "/etc/shadow" ]; then
			echo "[ /etc/shadow ]"
			#echo $(awk -F: '$2 !~ /^[*!]/ {print $0}' /etc/shadow)
			etcConf=$(awk -F: '$2 != "!!" && $2 != "*" && $2 !="" {split($2,a,"$"); hash_type=a[2]; printf "%s:$%s$****:%s:%s:%s:%s:%s:%s:%s\n",$1,hash_type,$3,$4,$5,$6,$7,$8,$9}' /etc/shadow)
			echo -e "$etcConf\n"
			echo ""
			userHash=$(awk -F':' '/:/ {split($2, arr, "\\$"); if (arr[2] != "!!" && arr[2] != "*" && arr[2] != "") print arr[2]}' "/etc/shadow")
			
			for x in $userHash; do
				if [ "$x" == "1" ]; then
					badCase=$((badCase + 1))
					break  # 1이 존재하면 더 이상 확인할 필요 없으므로 break
				fi
			done
		else
			fileExist=$((fileExist + 1))
			echo "[ /etc/shadow ]"
			echo "FILE NOT FOUND"
			echo ""
		fi

		if [ -e "/etc/login.defs" ]; then
			option=$(grep -i "ENCRYPT_METHOD" "/etc/login.defs" |  awk '{print $2}')
			echo "[ /etc/login.defs ]"
			echo "ENCRYPT_METHOD $option" 
			if [ "$option" == "MD5" ] || [ "$option" == "descrypt" ] || [ "$option" == "bigcrypt" ]; then
				badCase=$((badCase + 1))
			fi
		else
			fileExist=$((fileExist + 1))
			echo "[ /etc/login.defs ]"
			echo "FILE NOT FOUND"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
		if [ $badCase -ge 1 ]; then
			echo "[취약] /etc/shadow 파일에 encrypted_password 필드의 비밀번호가 MD5로 설정되어 있거나, /etc/login.defs 파일의 ENCRYPT_METHOD가 SHA256, SHA512로 설정되어 있지 않음"
			RESULT="BAD"
		elif [ $fileExist -ge 1 ]; then
			echo "[인터뷰] /etc/shadow 파일 또는 /etc/login.defs 파일이 존재하지 않음"
			RESULT="CHECK"
		elif [ $badCase -eq 0 ]; then
			echo "[양호] /etc/shadow 파일에 encrypted_password 필드의 비밀번호가 안전한 알고리즘으로 설정되어 있고, /etc/login.defs 파일의 ENCRYPT_METHOD가 SHA256, SHA512로 설정되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_073(){
	{	
		echo "양호: 관리자 그룹에 불필요한 계정이 등록되어 있지 않은 경우" 
		echo "취약: 관리자 그룹에 불필요한 계정이 등록되어 있는 경우" 
	} > $STANDARD_FILE

	{
		CASE=0
		echo "-------------------------------------------------------------------"
		echo "[ root group (${GROUP_CONF}) ]"
		if [ `cat ${GROUP_CONF} | grep '^root' | awk -F':' '$4!=null {print $4}' | wc -c` -ge 1 ]; then
			CASE=2
		fi
		cat ${GROUP_CONF} | grep '^root'
		
		echo "-------------------------------------------------------------------"
		if [ "${CASE}" -eq 2 ]; then
			echo "[확인] 관리자 그룹에 포함된 계정 목록 확인"
			RESULT="CHECK"
		else
			echo "[양호] 관리자 그룹에 포함된 계정이 root 이외에 없음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_074(){
  {
      echo "양호: 분기별 1회 이상 로그인 한 기록이 있고, 비밀번호를 변경하고 있는 경우"
      echo "취약: 분기별 1회 이상 로그인 한 기록이 없거나, 비밀번호를 변경하지 않은 경우"
  } > $STANDARD_FILE

  {
		LB_BadCase=0
        LB_CheckCase1=0
		LB_CheckCase2=0
        
        LS_Users=""
    	LI_TodayYear=`date +%Y-%m | awk -F"-" '{print $1}'`
    	LI_TodayMonth=`date +%Y-%m | awk -F"-" '{print $2}'`
    	LI_TodayQuarter=0

    	case ${LI_TodayMonth} in
         10|11|12)
           LI_TodayQuarter=4
           ;;
         07|08|09)
           LI_TodayQuarter=3
           ;;
         04|05|06)
           LI_TodayQuarter=2
           ;;
         01|02|03)
           LI_TodayQuarter=1
           ;;
         *)
           LI_TodayQuarter=0
           ;;
        esac

        echo "-------------------------------------------------------------------"
        echo "[ today ]"
        date +%Y-%m-%d
        echo ""
        if [ "${LI_TodayQuarter}" -eq 0 ]; then
			LB_CheckCase1=1
			echo "Today quarter can't check"
        elif [ `passwd --help | grep "\-\-status" | wc -l` -gt 0 ]; then
        	if [ -f "/etc/passwd" ]; then
            	if [ -f "/etc/shadow" ]; then
              		LS_Users=`cat "/etc/passwd" | awk -F":" '{print $1}'`
                	echo "[ login able account ]"
					for LS_User in ${LS_Users}; do
						if [ `passwd --status "${LS_User}" | grep " PS " | wc -l` -gt 0 ]; then
								echo "${LS_User}"
							    LI_ChangeMonth=`passwd --status "${LS_User}" | grep " PS " | awk -F" " '{print $3}' | awk -F"-" '{print $2}'`
			                    LI_ChangeYear=`passwd --status "${LS_User}" | grep " PS " | awk -F" " '{print $3}' | awk -F"-" '{print $1}'`
								      
								case ${LI_ChangeMonth} in
								10|11|12)
								LI_ChangeQuarter=4
								;;
								07|08|09)
								LI_ChangeQuarter=3
								;;
								04|05|06)
								LI_ChangeQuarter=2
								;;
								01|02|03)
								LI_ChangeQuarter=1
								;;
								*)
								LI_ChangeQuarter=0
								;;
								esac

								echo "password change date : "`passwd --status "${LS_User}" | grep " PS " | awk -F" " '{print $3}'`" (Q${LI_ChangeQuarter})"
					
								if [ "${LI_ChangeQuarter}" -eq 0 ]; then
									LB_CheckCase1=1
									echo "password change quarter can't check"
								elif [ `expr "${LI_TodayYear}" - "${LI_ChangeYear}"` -gt 1 ]; then
									LB_CheckCase2=1
								elif [ `expr "${LI_TodayYear}" - "${LI_ChangeYear}"` -eq 1 ]; then
									if [  "${LI_TodayQuarter}" -eq 1 -a "${LI_ChangeQuarter}" -eq 4 ]; then
									   LB_GoodCase=1
									else
									   LB_CheckCase2=1
									fi
								elif [ `expr "${LI_TodayQuarter}" - "${LI_ChangeQuarter}"` -gt 1 ]; then
									LB_CheckCase2=1
								fi 
							
							if [ `lastlog | grep -w "${LS_User} " | grep "\*\*" | wc -l` -gt 0 ]; then
								LB_CheckCase2=1
								echo "last login date : `lastlog | grep -w "${LS_User}" | awk -F" " '{print $0}'`"
								echo ""
							else
								LI_LoginYear=`lastlog | grep -w "${LS_User} " | awk -F" " '{print $NF}'`
								LS_LoginMonth=`lastlog | grep -w "${LS_User} " | awk -F" " '{print $(NF-4)}'`
								case ${LS_LoginMonth} in
								Oct|Nov|Dec)
								 LI_LoginQuarter=4
								 ;;
								Jul|Aug|Sep)
								 LI_LoginQuarter=3
								 ;;
								Apr|May|Jun)
								 LI_LoginQuarter=2
								 ;;
								Jan|Feb|Mar)
								 LI_LoginQuarter=1
								 ;;
								*)
								 LI_LoginQuarter=0
								 ;;
								esac
								echo "last login date : "`lastlog | grep -w "${LS_User}" | awk -F" " '{print $NF" "$(NF-4)" "$(NF-3)}'`" (Q${LI_ChangeQuarter})"
								if [ "${LI_LoginQuarter}" -eq 0 ]; then
									LB_CheckCase1=1
									echo "last login quarter can't check"
								elif [ `expr "${LI_TodayYear}" - "${LI_LoginYear}"` -gt 1 ]; then
									LB_CheckCase2=1
								elif [ `expr "${LI_TodayYear}" - "${LI_LoginYear}"` -eq 1 ]; then
									if [  "${LI_TodayQuarter}" -eq 1 -a "${LI_LoginQuarter}" -eq 4 ]; then
								    	LB_GoodCase=1
									else
								    	LB_CheckCase2=1
								   fi
								elif [ `expr "${LI_TodayQuarter}" - "${LI_LoginQuarter}"` -gt 1 ]; then
									LB_CheckCase2=1
								fi 
							fi  
							echo ""        
						fi
					done;       
	            else        
	                echo "/etc/shadow FILE NOT FOUND, can't check change password date"
	                LB_CheckCase1=1
	            fi  
	        else
	            echo "/etc/passwd NOT FOUND, can't check account"
	            LB_CheckCase1=1
	        fi
        else    
            echo "passwd의 \-S OPTION NOT FOUND, can't find login able account"
            LB_CheckCase1=1
        fi          


        echo "-------------------------------------------------------------------"
        if [ "${LB_BadCase}" -gt 0 ]; then
            echo "[취약]"
            RESULT="BAD"
		elif [ "${LB_CheckCase2}" -gt 0 ]; then
            echo "[확인] 분기별 1회 이상 로그인/비밀번호 변경 기록이 존재하지 않음, 회사 내부 규정이 존재하는지 담당자와의 인터뷰 필요"
            RESULT="CHECK"
        elif [ "${LB_CheckCase1}" -gt 0 ]; then
            echo "[확인] 로그인 가능한 계정의 로그인 기록과 암호 변경 기록이 분기별 1회 이상 존재하는지 확인"
            RESULT="CHECK"
        else        
            echo "[양호]모든 로그인 가능한 계정이 분기별 1회 이상 로그인 및 비밀번호를 변경하고 있음" 
            RESULT="GOOD"
        fi          
        echo "-------------------------------------------------------------------"  
  } > $STATUS_FILE
}

Unix_075(){
	{
		echo "양호 : 패스워드 필드에 값이 비어있지 않을 경우"
		echo "취약 : 패스워드 필드에 값이 비어 있을 경우('x', '!', '*' 제외)"
	} > $STANDARD_FILE

	{
		LI_FileExist=0
		LB_CheckCase=0
		LB_BadCase=0
		
		echo "-----------------------------------------------------------------"
		
		echo "[ /etc/shadow ]"
		if [ -f ${GS_ShadowConf} ]; then
			LI_FileExist=1
			LS_Users=`cat /etc/passwd | awk -F'^#' '{print $1}' | grep -v '/bin/false\|/sbin/nologin' | awk -F":" '{print $1}'`
			
			for LS_User in ${LS_Users}; do
				if [ `cat /etc/shadow | grep -w ${LS_User} | awk -F":" '{print $2}' | grep -w "\!\!" | wc -c` -le 3 -o `cat /etc/shadow | grep -w ${LS_User} | awk -F":" '{print $2}' | wc -w` -eq 0 ]; then
					LB_BadCase=1
				fi
			done
			cat /etc/shadow
		else
			LB_CheckCase=1
			echo "${GS_ShadowConf} FILE NOT FOUND" 
		fi
		echo "-----------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then 
			echo "[취약]" 
			RESULT="BAD"
		elif [ "${LB_CheckCase}" -gt 0 ]; then
			echo "[확인] ${GS_PasswdConf}파일이 존재하지 않음 "
			RESULT="CHECK"
		else
			echo "[확인] 영문 숫자 특수문자 2개 조합 시 10자리 이상, 3개 조합 시 8자리 이상인지 담당자의 인터뷰가 필요함 "
			RESULT="CHECK"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_081(){
	{
		echo "양호: 아래의 항목 중 해당 사항이 없는 경우"
		echo "1. /var/spool/cron/crontab/* 에 others 읽기 쓰기 권한이 없는 경우"
		echo "2. at 접근제어 파일의 소유자가 root 이고 권한이 640 이하인 경우"
		echo "3. cron 접근제어 파일의 소유자가 root이고 권한이 640 이하인 경우"
		echo "취약: cron 서비스 관련 설정 파일들이 양호 조건에 부합하지 않는 경우"
	} > $STANDARD_FILE

	{
		LS_CrontabConf=`ls -aldL /var/spool/cron/* 2>/dev/null | awk '{print $9}'`
		LS_ConfFiles="/etc/cron.deny /etc/cron.allow /etc/at.allow /etc/at.deny"
		LI_FileExist=0
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------" 
		if [ "${LS_CrontabConf}" == "" ]; then
			echo "[ /var/spool/cron/* ] /var/spool/cron/* FILE NOT FOUND"
		else
			for LS_File in ${LS_CrontabConf}; do
				echo "[ ${LS_File} ]"
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					ls -adlL ${LS_File}
					if [ `ls -adlL ${LS_File} | grep '^.......--.' | wc -l` -eq 0 ]; then
						LB_BadCase=1
					fi
				fi
				echo ""
			done
		fi
		
		for LS_File in ${LS_ConfFiles}; do
			echo "[ ${LS_File} ]"
			if [ -f ${LS_File} ]; then
				LI_FileExist=1
				ls -adlL ${LS_File}
				if [ `ls -adlL ${LS_File} | grep '^...-.-----' | wc -l` -eq 0 -o `ls -adlL ${LS_File} | awk '{print $3}' | grep "root" | wc -l` -eq 0 ]; then
					LB_BadCase=1
				fi
			else
				echo "${LS_File} FILE NOT FOUND"
			fi
			echo ""
		done
		
		if [ ${LI_FileExist} -eq 0 ]; then
			LB_CheckCase=1
		fi
		
		echo "-------------------------------------------------------------------" 
		if [ "${LB_BadCase}" -gt 0 ]; then
            echo "[취약]"
            RESULT="BAD"
        elif [ "${LB_CheckCase}" -gt 0 ]; then
            echo "[확인] Crontab 설정 파일이 존재하지 않음 담당자와 인터뷰가 필요함"
            RESULT="CHECK"
        else        
            echo "[양호] Crontab 설정 파일의 권한이 올바르게 되어있음" 
            RESULT="GOOD"
        fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE
}


Unix_082(){
	{
		echo "양호 : 시스템 주요 디렉터리의 권한에 others 쓰기 권한이 없을 경우"
		echo "취약 : 시스템 주요 디렉터리의 권한에 others 쓰기 권한이 있을 경우"
	} > $STANDARD_FILE

	{
		CNT=0
		BADCASE=0
		echo "-------------------------------------------------------------------"
		echo "[ system directory ]" 
		for sysdir in ${SYSTEM_DIR}; do
			ls -adlL ${sysdir}
			if [ -d ${sysdir} ]; then 
				CNT=1
				if [ `ls -adlL ${sysdir} | grep '^........-.' | wc -l` -eq 0 ]; then
					BADCASE=1 
				fi
			else
				echo "${sysdir} NOT FOUND"
			fi 
		done

		echo "-------------------------------------------------------------------"
		if [ "${CNT}" -gt 0 ]; then 
			if [ "${BADCASE}" -gt 0 ]; then 
				echo "[취약]" 
				RESULT="BAD" 
			else 
				echo "[양호] 주요 시스템 디렉터리에 others 쓰기 권한 없음" 
				RESULT="GOOD" 
			fi 
		else 
			echo "[양호] 주요 시스템 디렉터리 존재하지 않음" 
			RESULT="GOOD" 
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_083(){
	{
		echo "양호: 주요 시스템 디렉터리의 권한에 others 쓰기 권한이 없을 경우"
		echo "취약: 주요 시스템 디렉터리의 권한에 others 쓰기 권한이 있을 경우"
	} > $STANDARD_FILE

	{
		BADCASE=0
		echo "-------------------------------------------------------------------"
		echo "[ Startup Directory ]" 
		for SYSDIR in ${SYSSTART_IDR}; do
			if [ -d ${SYSDIR} ]; then 
				ls -adl ${SYSDIR}
				CNT=1
				if [ `ls -adl ${SYSDIR} | grep '^........-.' | wc -l` -eq 0 ]; then
					BADCASE=1 
				fi
			else
				echo "${SYSDIR} NOT FOUND"
			fi 
		done
		echo "-------------------------------------------------------------------"
		if [ "${CNT}" -gt 0 ]; then 
			if [ "${BADCASE}" -gt 0 ]; then 
				echo "[취약]" 
				RESULT="BAD" 
			else 
				echo "[양호] startup 디렉터리에 others 쓰기 권한 없음" 
				RESULT="GOOD" 
			fi 
		else 
			echo "[양호] startup 디렉터리 존재하지 않음" 
			RESULT="GOOD" 
		fi 
		
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_084(){
	{
		echo "양호: 시스템 주요 파일의 권한이 아래의 조건보다 낮게 부여된 경우"
		echo " - 1. /etc/passwd 권한: 644, 소유자 root"
		echo " - 2. /etc/shadow 권한: 600, 소유자 root"
		echo " - 3. /etc/hosts 권한: 644, 소유자 root"
		echo " - 4. /etc/(x)inetd.conf 권한: 600, 소유자 root"
		echo " - 5. /etc/syslogd.conf 권한: 644, 소유자 root"
		echo " - 6. /etc/services 권한:  644, 소유자 root"
		echo " - 7. /etc/hosts.lpd 권한: 640, 소유자 root"
		echo "취약: 시스템 주요 파일의 권한이 양호 조건에 부합하지 않는 경우"
	}  > $STANDARD_FILE

	{
		LS_Files1="/etc/passwd /etc/hosts /etc/syslog.conf /etc/rsyslog.conf /etc/services"
		LS_Files2="/etc/shadow /etc/inetd.conf /etc/xinetd.conf"
		LB_BadCase=0
		echo "-----------------------------------------------------------------"
		echo "[ PERMISSION : 644 ]"
		for LS_File in ${LS_Files1}; do
			if [ -f ${LS_File} ]; then
				ls -alL ${LS_File}
				if [ `ls -alL ${LS_File} 2> /dev/null| awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
					if [ `ls -alL ${LS_File} | grep '^-..-.--.--' | wc -l` -gt 0 ]; then
						GA_Null="0"
					else
						LB_BadCase=1
					fi
				else
					LB_BadCase=1
				fi
			else
				echo "${LS_File} NOT FOUND"
			fi
		
		done

		
		echo ""
		echo "[ PERMISSION : 640 ]"
		if [ -f /etc/hosts.lpd ]; then
			ls -alL /etc/hosts.lpd
			if [ `ls -alL /etc/hosts.lpd 2> /dev/null| awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
				if [ `ls -alL /etc/hosts.lpd | grep '^-..-.-----' | wc -l` -gt 0 ]; then
					GA_Null="0"
				else
					LB_BadCase=1
				fi
			else
				LB_BadCase=1
			fi
		else
			echo "/etc/hosts.lpd NOT FOUND"
		fi
		
		echo ""
		echo "[ PERMISSION : 600 ]"
		for LS_File in ${LS_Files2}; do
			if [ -f ${LS_File} ]; then
				ls -alL ${LS_File}
				if [ `ls -alL ${LS_File} 2> /dev/null| awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
					if [ `ls -alL ${LS_File} | grep '^-..-------' | wc -l` -gt 0 ]; then
						GA_Null="0"
					else
						LB_BadCase=1
					fi
				else
					LB_BadCase=1
				fi
			else
				echo "${LS_File} NOT FOUND"
			fi
		
		done


		echo "-----------------------------------------------------------------"
		if [ "${LB_BadCase}" -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		else
			echo "[양호] 시스템 주요 파일의 권한 및 소유자 설정이 양호함"
			RESULT="GOOD"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_087(){
	{
		echo "양호 : 컴파일러가 없거나 others 실행 권한이 없을 시 " 
		echo "취약 : 컴파일러에 others 실행 권한이 존재할 시" 
	}  > $STANDARD_FILE

	{
		CASE=0
		BADCASE=0
		echo "-------------------------------------------------------------------" 

		# 컴파일러들의 목록
		compilers=("gcc" "xlc" "tcc" "zapcc" "pgcc" "clang")

		#현황
		for compiler in "${compilers[@]}"; do
			echo "[ $compiler STATUS ]" 
			which_output=$(which $compiler 2>/dev/null)
			echo $which_output
			if [[ -n "$which_output" && "$which_output" != "no $compiler in"* ]]; then
				ls -alL ${which_output}
			else
				echo "$compiler NOT FOUND" 
			fi	
		done
		echo "" 
		#양/취판단
		for compiler in "${compilers[@]}"; do
			which_output=$(which $compiler 2>/dev/null)
			if [[ -n "$which_output" && "$which_output" != "no $compiler in"* ]]; then
				CASE=1
				if [ `ls -alL ${which_output} | grep '^-........-' | wc -l` -eq 0 ]; then 
					BADCASE=$(($BADCASE + 1))
					break
				fi
			fi
		done
		
		echo "-------------------------------------------------------------------" 
		if [ "${CASE}" -ge 1 ]; then 
			if [ "${BADCASE}" -ge 1 ]; then 
				echo "[취약] 컴파일러에 others 실행 권한이 존재하고 있음" 
				RESULT="BAD" 
			else 
				echo "[양호] 컴파일러에 others 실행 권한이 존재하지 않음" 
				RESULT="GOOD" 
			fi 
		else 
			echo "[양호] 컴파일러가 존재하지 않음" 
			RESULT="GOOD" 
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_091(){
	{
		echo "양호: 주요 실행파일의 권한에 SUID와 SGID에 대한 설정이 부여되어 있지 않은 경우"
		echo "취약: 주요 실행파일의 권한에 SUID와 SGID에 대한 설정이 부여된 경우"
	}  > $STANDARD_FILE
	{
		BADCASE=0
		echo "-------------------------------------------------------------------"
		echo "[ SUID SGID FILE CHECK ]"
		for check_file in ${SUGID_STICKY_CHECK}; do
			if [ -f ${check_file} ]; then
				tmp=""
				if [ -u ${check_file} ]; then
					BADCASE=1
					tmp=${tmp}"SUID "
				fi
			
				if [ -g ${check_file} ]; then
					BADCASE=1
					# echo "[ SGID check ]"
					tmp=${tmp}"SGID "
				fi

				if [ -k ${check_file} ]; then
					tmp=${tmp}"STICKY "
				fi
				
				if [ `echo $tmp | wc -w` -gt 0 ]; then
					echo "${tmp}" `ls -al ${check_file}`
				fi
			fi
		done
		if [ ${BADCASE} -eq 0 ]; then
			echo "SUID SGID file NOT FOUND"
		fi
		echo "-------------------------------------------------------------------"
			if [ ${BADCASE} -gt 0 ]; then			
				echo "[취약] "
				RESULT="BAD"
			else			
				echo "[양호] 주요 실행파일의 권한에 SUID와 SGID에 대한 설정이 부여되어 있지 않음"
				RESULT="GOOD"	
			fi				
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_092(){
   {
      echo "양호 : 아래의 항목 중 해당 사항이 없는 경우"
	  echo "1. 홈 디렉터리의 소유자와 실 사용자가 일치하지 않는 경우"
      echo "2. 계정간 중복 홈 디렉터리가 존재하는 경우"
      echo "3. 불필요한 others 쓰기 권한이 있는 경우"
      echo "취약 : 아래의 항목 중 해당하는 조건이 있는 경우"
      echo "1. 홈 디렉터리의 소유자와 실 사용자가 일치하지 않는 경우"
      echo "2. 계정간 중복 홈 디렉터리가 존재하는 경우"
      echo "3. 불필요한 others 쓰기 권한이 있는 경우"
   }  > $STANDARD_FILE

   {
      LB_BadCase=0
      LB_CheckCase1=0
      LB_CheckCase2=0
      echo "-------------------------------------------------------------------"
      if [ -f "/etc/passwd" ]; then
         echo "[ /etc/passwd file ]"
         cat /etc/passwd | awk -F"#" '{print $1}' | grep -wv "/sbin/nologin\|/bin/false" | sed '/^$/d' | awk -F":" '{print $1":"$3":"$6}'
         LS_PasswdConfig=`cat /etc/passwd | awk -F"#" '{print $1}' | grep -wv "/sbin/nologin\|/bin/false" | sed '/^$/d' | awk -F":" '{print $1":"$3":"$6}'`
         echo ""
         echo "[ home dir permission and UID ]"
         for LS_Config in ${LS_PasswdConfig}; do
            LS_User=`echo ${LS_Config} | awk -F ":" '{print $1}'`
            LS_UID=`echo ${LS_Config} | awk -F ":" '{print $2}'`
            LS_HomeDir=`echo ${LS_Config} | awk -F ":" '{print $3}'`
            
            if [ -d ${LS_HomeDir} ]; then
               if [ `cat /etc/passwd | grep -wv "/sbin/nologin\|/bin/false" | awk -F"#" '{print $1}' | awk -F":" '{print $6}' | grep -w ${LS_HomeDir} | wc -l` -gt 1 ]; then
                   LB_BadCase=1   
               fi

               ls -adlLn ${LS_HomeDir}
               if [ `ls -adlLn ${LS_HomeDir} | grep "^........-." | wc -l` -eq 0 ]; then
                      LB_CheckCase1=1
			   fi
			   
			   if [ `ls -adlLn ${LS_HomeDir} | awk '{print $3}' | grep -w "${LS_UID}\|0" | wc -l` -eq 0 ]; then
				  LB_BadCase=1
			   fi
            fi
         done
      else
         echo "/etc/passwd FILE NOT FOUND"
         LB_CheckCase2=1
      fi 

      echo "-------------------------------------------------------------------"
      if [ ${LB_BadCase} -eq 1 ]; then 
          echo "[취약]"
          RESULT="BAD" 
      elif [ ${LB_CheckCase1} -eq 1 ]; then 
         echo "[확인] 홈디렉터리에 others 쓰기 권한이 필요에 의해 설정되어 있는지 담당자와의 인터뷰가 필요함"
          RESULT="CHECK" 
      elif [ ${LB_CheckCase2} -eq 1 ]; then 
         echo "[확인] /etc/passwd 설정파일이 존재하지 않음"
          RESULT="CHECK" 
      else 
          echo "[양호] 홈 디렉터리의 소유자와 실 사용자가 일치하고, 계정간 중복 홈 디렉터리가 존재하지 않고, 불필요한 others 쓰기 권한이 없음"
          RESULT="GOOD" 
      fi 
      echo "-------------------------------------------------------------------"
   } > $STATUS_FILE
}

Unix_093(){
	{
		echo "양호 : 시스템 중요 파일에 world writable 파일이 존재하지 않거나, 존재시 설정 이유를 확인하고 있는 경우"
		echo "취약 : 시스템 중요 파일에 world writable 파일이 존재하나 해당 설정 이유를 확인하고 있지 않는 경우"
	}  > $STANDARD_FILE

	{
		if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then
			BADCASE=0
			echo "-------------------------------------------------------------------"
			for HOME in ${FIND_HOMEDIR_SORT}; do
				if [ $HOME != "/" -a $HOME != "/root" -a -d $HOME ]; then
					badfiles=`find $HOME -perm -2 -type f -exec ls -alL {} \; 2>/dev/null` 
					if [ `echo $badfiles | wc -w` -gt 0 ]; then
						echo "[ $HOME world writable file]"
						echo "$badfiles" | head -50
						BADCASE=1
						echo ""
					fi
				fi
			done
		
			if [ "${BADCASE}" -eq 0 ]; then
				echo "world writable file NOT FOUND"
			fi	
			echo "-------------------------------------------------------------------"

			if [ "${BADCASE}" -gt 0 ]; then
				echo "[확인] 불필요한 world writable 파일이 존재하는지 확인"
				RESULT="CHECK"
			else
				echo "[양호]world writable 파일이 존재하지 않음"
				RESULT="GOOD"
			fi
			echo "-------------------------------------------------------------------"
		elif [ `echo $FIND_CHECK | grep -i "2" | wc -l` -gt 0 ]; then
			echo "-------------------------------------------------------------------"
			echo "-------------------------------------------------------------------"
			echo "[확인] world writable 파일이 존재하는지, 존재한다면 설정 이유가 있는지 담당자와의 인터뷰 필요."
			echo "(find [각 계정의 홈 디렉터리] -perm -2 -type f -exec ls -alL {} \; 2>/dev/null 명령어 사용하여 world writable 파일 확인)" 
			RESULT="CHECK"
			echo "-------------------------------------------------------------------"
		fi
	} > $STATUS_FILE
}

Unix_094(){
	{
		echo "양호 : crontab 참조파일에 others 쓰기 권한이 없는 경우"
		echo "취약 : crontab 참조파일에 others 쓰기 권한이 있는 경우"
	}  > $STANDARD_FILE

	{
		FILEEXIST=0
		BADCASE=0
		DIRLIST=""
		echo "-------------------------------------------------------------------"
		if [ -d ${CRONTAB_DIR} ];then
			DIRLIST=`cat /var/spool/cron/crontabs/* | egrep ".sh|.pl" | awk '{print $6}'`
		else
			DIRLIST=`cat /var/spool/cron/* | egrep ".sh|.pl" | awk '{print $6}' `
		fi
		
		if [ `echo ${DIRLIST} | wc -w` -eq 0 ]; then
			echo "crontab FILE NOT FOUND"
		else
			for cronfile in ${DIRLIST}; do
				if [ -f ${cronfile} ]; then
					FILEEXIST=1
					ls -alL ${cronfile}
					if [ `ls -alL ${cronfile} | grep -i '^........w.' | wc -l` -gt 0 ]; then
						BADCASE=1 
					fi
				fi
			done
			if [ "${FILEEXIST}" -eq 0 ]; then
				echo "crontab FILE NOT FOUND"
			fi
		fi
		
		echo "-----------------------------------------------------------------"
		if [ "${FILEEXIST}" -gt 0 ]; then
			if [ "${BADCASE}" -gt 0 ]; then
				echo "[취약]"
				RESULT="BAD"
			else
				echo "[양호] crontab 참조파일에 others 쓰기 권한이 없음"
				RESULT="GOOD"
			fi
		else
			echo "[양호] crontab에 의해 참조되고 있는 파일이 없음"
			RESULT="GOOD"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_095(){
   { 
		echo "양호: 소유자가 존재하지 않는 파일 및 디렉터리가 존재하지 않는 경우 "
		echo "취약: 소유자가 존재하지 않는 파일 및 디렉터리가 존재하는 경우"
   }  > $STANDARD_FILE
	{
	  LS_HomeDirectorySort=`cat /etc/passwd | awk -F"#" '{print $1}' | grep -v ":nosh\|sbin/nologin\|bin/false\|:/home\|:/root:\|:/:" | awk -F":" '{print $6}' | sort -u`" "`ls -dl /home/* | awk '{print $9}'`
      LB_BadCase=0
      echo "-------------------------------------------------------------------"
      for LS_Directory in ${LS_HomeDirectorySort}; do
		LS_BadFiles=`find ${LS_Directory} \( -type d -o -type f \) -a \( -nouser -o -nogroup \) -xdev 2>/dev/null`
		echo "[ ${LS_Directory} nouser nogroup File & Directory ]"
		if [ `echo ${LS_BadFiles} | wc -w` -gt 0 ]; then
		   LB_BadCase=1
		   for LS_File in ${LS_BadFiles}; do
			  ls -al ${LS_File}
		   done
		else
		   echo "FILE NOT FOUND"
		fi
		echo ""
      done
      echo "-------------------------------------------------------------------"
      if [ ${LB_BadCase} -gt 0 ]; then
         echo "[취약] "
         RESULT="BAD"
      else
         echo "[양호] 존재하지 않는 UID 및 GID를 가진 파일 및 디렉터리가 존재하지 않음"
         RESULT="GOOD"
      fi
      echo "-------------------------------------------------------------------"
   } > $STATUS_FILE 2> /dev/null
}


Unix_096(){ 
	{
		echo "양호 : 사용자, 시스템 시작파일 및 환경파일에 others에 읽기/쓰기 권한이 없을 경우" 
		echo "취약 : 사용자, 시스템 시작파일 및 환경파일에 others에 읽기 혹은 쓰기 권한이 있을 경우"
	}  > $STANDARD_FILE 
 
	{ 
		LB_BadCase=0
		LI_FileExist=0
		LS_HomeDirectory=`cat ${GS_PasswdConf} | awk -F"#" '{print $1}' | grep -v "sbin/nologin" | grep -v "bin/false" | awk -F":" '{print $1":"$6}'`
		echo "-----------------------------------------------------------------"
		echo "[ HOME Directory ]"
		for LS_Directory in ${LS_HomeDirectory}; do
		LS_User=`echo ${LS_Directory} | awk -F":" '{print $1}'`
		LS_Home=`echo ${LS_Directory} | awk -F":" '{print $2}'`
		if [ -d ${LS_Home} ];then
		LI_FileExist=0
		for LS_File in ${GS_ENVFiles}; do 
		   if [ -f ${LS_Home}/${LS_File} ]; then 
			  LI_FileExist=1
			  echo "USER:${LS_User}"
			  ls -alL ${LS_Home}/${LS_File} # 현황 출력
			  if [ `ls -alL ${LS_Home}/${LS_File} | grep "^-......---" | wc -l` -eq 0 ]; then 
				 LB_BadCase=1
			  fi
		   fi
		done

		if [ ${LI_FileExist} -eq 0 ]; then
		   echo "${LS_User} : ${LS_Home} NOT IN ENV_FILE"
		fi
		else
		echo "${LS_User} : ${LS_Home} NOT FOUND"
		fi
		echo ""
		done
		echo "-----------------------------------------------------------------"  
		if [ ${LB_BadCase} -eq 1 ]; then 
		echo "[취약] "
		RESULT="BAD" 
		else 
		echo "[양호] 사용자 환경변수 파일의 권한이 올바르게 되어 있음"
		RESULT="GOOD" 
		fi 
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE 
} 

Unix_108(){
	{
		echo -e "양호: 디렉터리 내 로그 파일들의 권한이 644 이하일 때\n※ 예시 : 디렉터리 내 로그 파일들의 권한이 owner에 읽기(r), 쓰기(w), group에 읽기(r), other에 읽기(r)로 할당한 경우 (파일 권한이 644 일 때 양호)\n※ /var/log/lastlog의 경우는 664 (권한 변경 불가), /var/log/wtmp의 경우는 664 (권한 변경 불가), /var/log/btmp의 경우는 660 (권한 변경 불가)"
		echo -e "취약: 디렉터리 내 로그 파일들을 소유자 이외의 사용자가 수정 가능할 때\n※ 예시 : 디렉터리 내 로그 파일들을 소유자 이외의 사용자가 수정이 가능한 경우(owner 외 쓰기(w) 권한 할당 시 취약)\n※ /var/log/lastlog의 경우는 664 (권한 변경 불가), /var/log/wtmp의 경우는 664 (권한 변경 불가), /var/log/btmp의 경우는 660 (권한 변경 불가)"
	} > $STANDARD_FILE
	{
		#/var/log/lastlog의 경우는 664 (권한 변경 불가)
		#/var/log/wtmp의 경우는 664 (권한 변경 불가)
		#/var/log/btmp의 경우는 660 (권한 변경 불가)
		badCase=0
		echo "-------------------------------------------------------------------"
		echo "[ /var/log/FILES(644) ]"
		for x in ${CHECK_LOG_FILE}; do
			file_path="${CHECK_LOG_DIR}${x}" 
			if [ -e "${file_path}" ] && [ -f "${file_path}" ]; then
				ls -al "${file_path}" 2>/dev/null
				if [ $(ls -l "${file_path}" | grep '^-..-.--.--' | wc -l) -eq 0 ]; then
					badCase=$((badCase + 1))
				fi
			fi
		done

		if [ -f "/var/log/lastlog" ]; then
			echo "[ /var/log/lastlog(664) ]"
			ls -al "/var/log/lastlog"
			if [ $(ls -l "/var/log/lastlog" | grep '^-..-..-.--' | wc -l) -eq 0 ]; then
				badCase=$((badCase + 1))
			fi
		fi
		echo ""

		echo ""
		if [ -f "/var/log/wtmp" ]; then
			echo "[ /var/log/wtmp(664) ]"
			ls -al "/var/log/wtmp"
			if [ $(ls -l "/var/log/wtmp" | grep '^-..-..-.--' | wc -l) -eq 0 ]; then
				badCase=$((badCase + 1))
			fi
		fi
		echo ""
		
		if [ -f "/var/log/btmp" ]; then
			echo "[ /var/log/btmp(660) ]"
			ls -al "/var/log/btmp"
			if [ $(ls -l "/var/log/btmp" | grep '^-..-..----' | wc -l) -eq 0 ]; then
				badCase=$((badCase + 1))
			fi
		fi
		echo ""
		
		echo "-------------------------------------------------------------------"
		if [ $badCase -ge 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		else
			echo "[양호] /var/log/ 디렉터리 내 로그 파일들의 권한이 644 이하로 설정되어 있음"
			RESULT="GOOD" 
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


Unix_109(){ 
	{ 
		echo "양호 : 1. syslog 로그 기록 정책이 내부 정책에 부합하게 설정되어 있는 경우" 
		echo "2. syslog 설정에서 auth 또는 authpriv 가 활성화된 경우 (su 명령 로그)"
		echo "취약 : 1. syslog 로그 기록 정책이 내부 정책에 부합하게 설정되지 않은 경우" 
		echo "2. syslog 설정에서 auth 또는 authpriv 가 활성화되지 않은 경우(su 명령 로그)"
	}  > $STANDARD_FILE 2> /dev/null 
	 
	{ 
	
		LS_Result=""
		LI_FileExist=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LB_BadCase=0
		
		echo "-------------------------------------------------------------------" 
		PROCESS_CHECKER syslog
		LS_Result=`PROCESS_CHECKER syslog`
		if [ "${PCK}" -gt 0 ]; then
			if [ `echo "${LS_Result}" | grep "rsyslog" | wc -l` -gt 0 ]; then
				if [ -f "/etc/rsyslog.conf" ]; then
					LI_FileExist=1
					echo "[ /etc/rsyslog.conf ]"
					cat "/etc/rsyslog.conf" | awk -F "#" '{print $1}' | sed '/^$/d'
					if [ `cat "/etc/rsyslog.conf" | awk -F "#" '{print $1}' | grep -v "auth.none" | grep -v "authpriv.none" | grep "auth" | wc -l` -gt 0 ]; then
						LB_CheckCase1=1
					fi
					
					#rsyslog 8.33 버전 이상 includ() 존재할 경우
					if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 1p` -ge 8 ]; then
						if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 2p` -ge 33 ]; then
							if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | wc -l` -gt 0 ]; then
								file_name=`cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | grep -oP 'file="\K[^"]+'`
								file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
								
								#파일이 존재할 경우
								echo ""
								echo "[ ls -a $file_name ]"
								ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
								if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' |wc -l` -gt 0 ]; then
									for file in ${file_list}; do
										#auth, authpriv 확인
										if [ `cat ${file} | awk -F "#" '{print $1}' | grep -v "auth.none" | grep -v "authpriv.none" | grep "auth" | wc -l` -gt 0 ]; then
											echo ""
											echo "[ $file ]"
											cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
											LB_CheckCase1=1
										fi
									done
								else
									echo $file_name " : conf file does not exist"
									echo ""
								fi
							fi
						fi
					fi
					
					#includeconfig
					if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -i '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
						file_name=`cat /etc/rsyslog.conf | awk -F '#' '{print $1}' | grep -i '^\s*\$IncludeConfig' | awk '{print $2}'`
						file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
	
						#파일이 존재할 경우
						echo ""
						echo "[ ls -a $file_name ]"
						ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
						if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' | wc -l` -gt 0 ]; then
							for file in ${file_list}; do
								#auth, authpriv 확인
								if [ `cat ${file} | awk -F "#" '{print $1}' | grep -v "auth.none" | grep -v "authpriv.none" | grep "auth" | wc -l` -gt 0 ]; then
									echo ""
									echo "[ $file ]"
									cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
									LB_CheckCase1=1
								fi
							done
						else
							echo $file_name " : conf file does not exist"
							echo ""
						fi
					fi
					
					#rsyslog.conf , include(), includeconfig 파일 중 check가 없는지 확인.
					if [ $LB_CheckCase1 -eq 0 ]; then
						LB_BadCase=1
					fi
				fi 
			fi
			if [ `echo "${LS_Result}" | grep -v "rsyslog" | grep "syslog" | wc -l` -gt 1 ]; then
				if [ -f "/etc/syslog.conf" ]; then
					LI_FileExist=1
					echo "[ /etc/syslog.conf ]"
					cat "/etc/rsyslog.conf" | awk -F"#" '{print $1}' | sed '/^$/d'
					if [ `cat "/etc/syslog.conf" | awk -F"#" '{print $1}' | grep -v "auth.none" | grep -v "authpriv.none" | grep "auth" | wc -l` -gt 0 ]; then
						LB_CheckCase1=1
					else
						LB_BadCase=1
					fi
				fi
			fi
			
			if [ '${LI_FileExist}' -eq 0 ]; then
				LB_CheckCase4=1
				echo "(r)syslog config FILE NOT FOUND"
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ (r)syslog ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ (r)syslog ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ (r)syslog ]"
			echo "(r)syslog 서비스가 구동중이지 않음"
			echo ""
			LB_BadCase=1
		fi

		echo "-------------------------------------------------------------------" 
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] syslog 로그 기록 정책이 내부 정책에 부합하게 설정되어 있는지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] (r)syslogd가 구동중이지만 /etc/(r)syslog.conf 파일을 확인할 수 없음"
			RESULT="CHECK"
		fi
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 2> /dev/null 
}

Unix_112(){
	{
		echo "양호: syslog 로그 기록 정책 또는 다른 로그 프로그램으로 cron 로그가 기록되는 경우"
		echo "취약: syslog 로그 기록 정책 또는 다른 로그 프로그램으로 cron 로그가 기록되지 않는 경우"	
	}  > $STANDARD_FILE
	{

	LB_GoodCase=0
	LB_BadCase=0
	LB_CheckCase2=0
	LB_CheckCase3=0
	LB_CheckCase4=0
	LB_CheckCase5=0

	echo "-------------------------------------------------------------------" 

	PROCESS_CHECKER cron

	if [ ${PCK} -eq 1 ]; then
		PROCESS_CHECKER syslog
		if [ ${PCK} -eq 1 ]; then
			if [ `PROCESS_CHECKER syslog | grep -i 'rsyslog' | wc -l` -gt 0 ]; then
				echo "[ /etc/rsyslog.conf ]"
				if [ -f /etc/rsyslog.conf ]; then
					# 주석 제외한 cron 라인 존재 시
					if [ `cat /etc/rsyslog.conf | awk -F"#" '{print $1}' | grep -ie "^cron" -ie 'include\([^)]*\)' -ie '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
						cat /etc/rsyslog.conf | awk -F"#" '{print $1}' | grep -ie "^cron" -ie 'include\([^)]*\)' -ie '^\s*\$IncludeConfig'
						LB_GoodCase=1
					else
						echo "cron logging NOT FOUND"
					fi
					# rsyslogd 8.33 이상에서 inlcude 존재할 경우
					if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 1p` -ge 8 ]; then
						if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 2p` -ge 33 ]; then
							if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | wc -l` -gt 0 ]; then
								file_name=`cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | grep -oP 'file="\K[^"]+'`
								file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
								
								#파일이 존재할 경우
								echo ""
								echo "[ ls -a $file_name ]"
								ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
								if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' |wc -l` -gt 0 ]; then
									for file in ${file_list}; do
										#cron 확인
										if [ `cat ${file} | awk -F "#" '{print $1}' | grep -i "^cron" | wc -l` -gt 0 ]; then
											echo ""
											echo "[ $file ]"
											cat ${file} | awk -F "#" '{print $1}' | grep -i "^cron" | sed '/^$/d'
											LB_GoodCase=1
										fi
									done
								else
									LB_CheckCase5=1
									echo $file_name " : conf file does not exist"
									echo ""
								fi
							fi
						fi
					fi
					
					#includeconfig
					if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -i '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
						file_name=`cat /etc/rsyslog.conf | awk -F '#' '{print $1}' | grep -i '^\s*\$IncludeConfig' | awk '{print $2}'`
						file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
	
						#파일이 존재할 경우
						echo ""
						echo "[ ls -a $file_name ]"
						ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
						if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' | wc -l` -gt 0 ]; then
							for file in ${file_list}; do
								#auth, authpriv 확인
								if [ `cat ${file} | awk -F "#" '{print $1}' | grep -i "^cron" | wc -l` -gt 0 ]; then
									echo ""
									echo "[ $file ]"
									cat ${file} | awk -F "#" '{print $1}' | grep -i "^cron" | sed '/^$/d'
									LB_GoodCase=1
								fi
							done
						else
							LB_CheckCase5=1
							echo $file_name " : conf file does not exist"
							echo ""
						fi
					fi
					
					#rsyslog.conf , include(), includeconfig에서 goodcase 없는지 확인.
					if [ $LB_GoodCase -eq 0 ]; then
						LB_BadCase=1
					fi

				else
					echo "/etc/rsyslog.conf NOT FOUND"
					#rsyslog.conf 파일 확인 불가
					LB_CheckCase4=1
				fi
				

			else
				echo "[ /etc/syslog.conf ]"
				if [ -f /etc/syslog.conf ]; then
					# 주석 제외한 cron 라인 존재 시
					if [ `cat /etc/syslog.conf | awk -F"#" '{print $1}' | grep -i 'cron' | wc -l` -gt 0 ]; then
						cat /etc/syslog.conf | awk -F"#" '{print $1}' | grep -i "^cron"
						LB_GoodCase=1   
					else
						LB_BadCase=1
						echo "syslog.conf cron logging NOT FOUND"
					fi
				else
					echo "/etc/syslog.conf FILE NOT FOUND"
					#syslog.conf 파일 확인 불가
					LB_CheckCase4=1
				fi
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ (r)syslog ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ (r)syslog ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			LB_BadCase=1
			echo "[ (r)syslog ]"
			echo " (r)syslog SERVICE NOT ACTIVATE"
			echo ""
		fi
	
	elif [ ${INETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase2=1
		echo "[ cron ]"
		echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
		echo ""
	elif [ ${XINETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase3=1
		echo "[ cron ]"
		echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
		echo ""
	else
		echo "[ cron ]"
		echo " cron SERVICE NOT ACTIVATE"
		echo ""
	fi
	
	echo "-------------------------------------------------------------------"
	if [ ${LB_BadCase} -eq 1 ]; then
		echo "[취약]"
		RESULT="BAD"
	elif [ ${LB_CheckCase2} -eq 1 ]; then
		echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_CheckCase3} -eq 1 ]; then
		echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_CheckCase4} -eq 1 ]; then
		echo "[확인] (r)syslog가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_CheckCase5} -eq 1 ]; then
		echo "[확인] rsyslog.d 디렉터리 내에 로그 정책이 설정된 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_GoodCase} -eq 1 ]; then
		echo "[양호] cron log 옵션이 양호하게 설정 되어 있음"
		RESULT="GOOD"
	else 
		echo "[양호] cron 서비스 사용 안함"
		RESULT="GOOD"
	fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_115(){
	{
		echo "양호: 접속기록 등의 보안 로그, 응용 프로그램 및 시스템 로그 기록에 대해 정기적으로 검토, 분석, 리포트 작성 및 보고 등의 조치가 이루어지는 경우"
		echo "취약: 위 로그 기록에 대해 정기적으로 검토, 분석, 리포트 작성 및 보고 등의 조치가 이루어지지 않는 경우"	
	}  > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "INTERVIEW"
		echo "-------------------------------------------------------------------"
		RESULT="CHECK"
		echo "[확인] 운영 담당자와 인터뷰를 통해 정기적인 로그 감사 진행여부 확인 필요"
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_118(){
	{
		echo "양호: 패치 적용 정책을 수립하여 주기적으로 패치 관리를 하고 있는 경우"
		echo "취약: 패치 적용 정책을 수립하지 않고 주기적으로 패치 관리를 하지 않는 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "[ Server version check ]"
		cat /etc/*-release
		echo ""
		echo "-------------------------------------------------------------------"
		echo "[확인] Linux는 서버에 설치된 패치 리스트의 관리가 불가능하므로 운영담당자와 인터뷰를 통해 패치 관리여부 확인 필요"
		RESULT="CHECK"
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_121(){
	{
		echo "양호: PATH 환경변수에 \".\" 이 맨 앞이나 중간에 포함되지 않은 경우"
		echo "취약: PATH 환경변수에 \".\" 이 맨 앞이나 중간에 포함되어 있는 경우"
	} > $STANDARD_FILE
	
	{
	  LB_BadCase=0
      echo "-------------------------------------------------------------------"
      echo "[ PATH env ]"
      echo $PATH
      echo ""
	  echo "[ Check PATH ]"
	  echo ${PATH} | tr ":" "\n"
	  
	  if [ `echo ${PATH} | grep "\./" | wc -l` -gt 0 -o `echo ${PATH} | grep ":\.:" | wc -l` -gt 0 ]; then
		 LB_BadCase=1
	  fi
		
      echo "-------------------------------------------------------------------"
      if [ ${LB_BadCase} -eq 1 ]; then
         echo "[취약] "
         RESULT="BAD"
      else
	   echo "[양호] PATH 환경변수에 \".\" 이 맨 앞이나 중간에 포함되지 않음"
	   RESULT="GOOD"
      fi
      echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_122(){
	{
		echo "양호 : UMASK 값이 022 이상으로 설정된 경우"
		echo "취약 : UMASK 값이 022 이상으로 설정되지 않은 경우"
	} > $STANDARD_FILE
	{
	    shellList=("bash" "csh" "ksh" "tcsh" "sh")
	{
	if [ -e /etc/profile ]; then
		echo "-------------------------------------------------------------------"
		echo "[ /etc/profile ]"
		cat /etc/profile
		echo ""
		echo ""
	else
		echo "/etc/profile NOT FOUND"
	fi
	
	for x in "${shellList[@]}"; do
		if [ -e "/etc/${x}rc" ] ; then
			echo "-------------------------------------------------------------------"
			echo "[ /etc/${x}rc ]"
			cat "/etc/${x}rc"
			echo ""
			echo ""
		else
			echo "-------------------------------------------------------------------"
			echo "[ /etc/${x}rc NOT FOUND ]"
			echo ""
			echo ""
		fi
	done
	
	
    while IFS=: read -r userName _ _ _ _ userHome userShell _; do
        for x in "${shellList[@]}"; do
            if [ "$userShell" == "/bin/${x}" ] || [ "$userShell" == "/sbin/${x}" ] || [ "$userShell" == "/usr/bin/${x}" ]; then
                if [ -e "${userHome}/.${x}_profile" ] ; then
                    echo "-------------------------------------------------------------------"
					echo "[ ${userHome}/.${x}_profile ]"
                    cat "${userHome}/.${x}_profile"
                    echo ""
					echo ""
				else
					echo
					echo "-------------------------------------------------------------------"
					echo "[ ${userHome}/.${x}_profile NOT FOUND ]"
					echo ""
					echo ""
                fi
                
                if [ -e "${userHome}/.${x}rc" ] ; then
					echo "-------------------------------------------------------------------"
                    echo "[ ${userHome}/.${x}rc ]"
					cat "${userHome}/.${x}rc"
					echo ""
					echo ""
				else
					echo "-------------------------------------------------------------------"
					echo "[ ${userHome}/.${x}rc NOT FOUND ]"
					echo ""
					echo ""
                fi
                
                if [ -e "${userHome}/.profile" ] ; then
					echo "-------------------------------------------------------------------"
                    echo "[ ${userHome}/.profile ]"
					cat "${userHome}/.profile"
					echo ""
					echo ""
				else
					echo "-------------------------------------------------------------------"
					echo "[ ${userHome}/.profile NOT FOUND ]"
					echo ""
					echo ""
                fi
            else
                continue
            fi
        done
    done < /etc/passwd
	
	} > "$RESULTDIR/umask-raw_data.txt"

	echo "-------------------------------------------------------------------"
    echo "[확인] umask-raw_data.txt 파일 참고"
	RESULT="CHECK"
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_127(){
	{
		echo "양호 : /etc/pam.d/password-auth, /etc/pam.d/common-auth, /etc/pam.d/system-auth, /etc/security/faillock.conf 파일에 계정 잠금 임계값 설정이 존재하는 경우"
		echo "취약 : /etc/pam.d/password-auth, /etc/pam.d/common-auth, /etc/pam.d/system-auth, /etc/security/faillock.conf 파일에 계정 잠금 임계값 설정이 존재하지 않는 경우"
	} > $STANDARD_FILE
   {
	LB_CheckCase1=0
	LB_CheckCase2=0

	echo "-------------------------------------------------------------------"
	
	# 공통
	version=$(
		(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null || \
		grep -oP '\d+(?=\.)' /etc/os-release 2>/dev/null) || \
		grep -oP '\d+' /etc/redhat-release 2>/dev/null | head -n 1 || \
		awk '{print $NF}' /etc/redhat-release 2>/dev/null | awk -F"." '{print $1}'
	)
	echo "[ OS Version ]"
	echo "version : " $(grep -hE "PRETTY_NAME|DISTRIB_DESCRIPTION|release" /etc/*-release | head -n 1 | sed 's/.*=\s*//; s/\"//g')
	echo ""
	#sshd_config Permitemptypasswords 설정 확인
	for FILE in ${GS_SSHDConf}; do
	if [ -f ${FILE} ]; then
		LI_FileExist=1
		echo ""
		echo "[ sshd config (${FILE}) ]"
		cat /etc/ssh/sshd_config | grep -i permitemptypasswords
		echo ""
	fi
	done

	if [ "${LI_FileExist}" -eq 0 ]; then
		LB_CheckCase1=1
		echo "sshd config NOT FOUND"
		echo ""
	fi

	# ubuntu 사용시
	if [ $version -ge 20 ]; then
		if [ -f "/etc/pam.d/common-auth" ]; then
			echo "[ /etc/pam.d/common-auth ]"
			echo "계정잠금임계값_RAWDATA.txt 확인"
			echo ""
			#faillock.so 모듈이 있을 경우 faillock.conf 출력
			if [ `cat /etc/pam.d/common-auth | grep -v "#" | grep faillock.so | wc -l` -gt 0 ]; then
				#모듈 순서 체크
				CHECK=$(awk '!/^#|^$/' /etc/pam.d/common-auth | awk '
				BEGIN { expected_step = 1 }
				{
					if ($0 ~ /pam_faillock.so preauth/ && expected_step == 1) expected_step = 2;
					else if ($0 ~ /pam_unix.so/ && expected_step == 2) expected_step = 3;
					else if ($0 ~ /pam_faillock.so authfail/ && expected_step == 3) expected_step = 4;
					else if ($0 ~ /pam_deny.so/ && expected_step == 4) expected_step = 5;
				}
				END {
					if (expected_step == 5) print 1;
					else {
						print 2;
						exit 1;
					}
				}')
				# 모듈 순서가 올바를 경우 faillock.conf 출력
				if [ $CHECK -eq 1 ]; then
					echo "[ /etc/security/faillock.conf ]"
					if [ -f "/etc/security/faillock.conf" ]; then
							cat "/etc/security/faillock.conf" | grep -oP '^\s*#?\s*deny\s*=\s*[0-9]+'
							echo ""
					else
						LB_CheckCase1=1
						echo "/etc/security/faillock.conf NOT FOUND"
						echo ""
					fi
				fi
			else
				echo "pam_faillock.so NOT FOUND"
				echo ""
			fi
		else
			LB_CheckCase1=1
			echo "/etc/pam.d/common-auth NOT FOUND"
			echo ""
		fi

	#redhat 8버전 이상
	elif [ $version -ge 8 ]; then
		# with-faillock 활성화 확인
		faillockCheck=$(authselect current | grep -i "with-faillock")
		echo "[ authselect current ]"
		echo `authselect current`
		echo ""
		#with-faillock 활성화 시 faillock.conf 출력
		if [ -n "$faillockCheck" ]; then
			if [ -f "/etc/security/faillock.conf" ]; then
				echo "[ /etc/security/faillock.conf ]"
				cat "/etc/security/faillock.conf" | grep -oP '^\s*#?\s*deny\s*=\s*[0-9]+'
				echo ""
			else
				echo "[ /etc/security/faillock.conf ]"
				echo "FILE NOT FOUND"
				echo ""
				LB_CheckCase1=1
			fi
		else
			echo "[ /etc/pam.d/system-auth ]"
			if [ -f "/etc/pam.d/system-auth" ]; then
				echo "계정잠금임계값_RAWDATA.txt 확인"
				echo ""
			else
				echo "FILE NOT FOUND"
				echo ""
				LB_CheckCase1=1
			fi
			echo "[ /etc/pam.d/password-auth ]"
			if [ -f "/etc/pam.d/password-auth" ]; then
				echo "계정잠금임계값_RAWDATA.txt 확인"
				echo ""
			else
				echo "FILE NOT FOUND"
				echo ""
				LB_CheckCase1=1
			fi
		fi
		
	#Redhat 6버전 이상	
	elif [ $version -ge 6 ]; then
		echo "[ /etc/pam.d/system-auth ]"
		if [ -f "/etc/pam.d/system-auth" ]; then
			echo "계정잠금임계값_RAWDATA.txt 확인"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
			LB_CheckCase1=1
		fi
		echo "[ /etc/pam.d/password-auth ]"
		if [ -f "/etc/pam.d/password-auth" ]; then
			echo "계정잠금임계값_RAWDATA.txt 확인"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
			LB_CheckCase1=1
		fi

	elif [ $version -eq 5 ]; then
		echo "[ /etc/pam.d/system-auth ]"
		if [ -f "/etc/pam.d/system-auth" ]; then
			echo "계정잠금임계값_RAWDATA.txt 확인"
			echo ""
		else
			echo "FILE NOT FOUND"
			echo ""
			LB_CheckCase1=1
		fi
	elif [ $version -le 4 ]; then
		LB_CheckCase2=1
	
	# 버전 정보 확인 불가
	else
		LB_CheckCase2=1
	
	fi

	


	echo "-------------------------------------------------------------------"
	if [ "${LB_CheckCase1}" -eq 1 ]; then 
		echo "[확인] 설정파일이 존재하지 않음" 
		RESULT="CHECK" 
	elif [ "${LB_CheckCase2}" -eq 1 ]; then 
		echo "[확인] OS 버전정보 확인불가. 계정잠금임계값_RAWDATA.txt 확인 필요"
		RESULT="CHECK" 
	else
		echo "[확인] 계정잠금임계값_RAWDATA.txt 확인 필요"
		RESULT="CHECK" 
	fi 
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 
}

#계정잠금임계값 2024년도 기준 코드
: << 'EOF'
Unix_127(){
	{
		echo "양호 : /etc/pam.d/password-auth, /etc/pam.d/system-auth, /etc/security/faillock.conf 파일에 계정 잠금 임계값 설정이 존재하는 경우"
		echo "취약 : /etc/pam.d/password-auth, /etc/pam.d/system-auth, /etc/security/faillock.conf 파일에 계정 잠금 임계값 설정이 존재하지 않는 경우"
	} > $STANDARD_FILE
   {
	statusCode=0
	i=0
	typeFlag=0
	fileExist=0
	statusPam=0
	LM_Ment=""
    fileList=("system-auth" "password-auth")

	# 버전이 8 이상인지 확인
	echo "-------------------------------------------------------------------"
	version=$(cat /etc/os-release | grep -i "VERSION_ID" | awk -F"\"" '{print $2}' | awk -F"." '{print $1}')
	echo "version : $version"
	echo ""
	if [ $version -ge 8 ]; then
	# with-faillock 활성화 확인
		faillockCheck=$(authselect current | grep -i "with-faillock")
		if [ -n "$faillockCheck" ]; then
			echo "[ authselect current ]"
			echo `authselect current`
			echo ""
			typeFlag=1
			if [ -f "/etc/security/faillock.conf" ]; then
				echo "[ faillock.conf ]"
				#cat /etc/security/faillock.conf
				fConf=$(cat "/etc/security/faillock.conf" | grep -v '^#' | grep -oP 'deny\s*=\s*\K[0-9]+' | awk -F"=" '{print $1}')
				# deny가 존재하지 않을 때 deny=3 값을 넣어줌 (default가 3이므로)
				if [ -z "$fConf" ]; then
					fConf=3 # default=3
				fi
				
				# deny 1이상
				if [ $fConf -ge 1 ]; then
					statusCode=1000
				else
					statusCode=2000
				fi
				echo "deny = $fConf"
				echo ""
			else
				echo "[ faillock.conf ]"
				echo "FILE NOT FOUND"
				echo ""
				fileExist=1
			fi
		fi
	fi
	
	if [ $version -le 7 ] || [ $typeFlag -eq 0 ]; then
		for item in "${fileList[@]}"
			do
			if [ -f "/etc/pam.d/$item" ]; then
				echo "-------------------------------------------------------------------"
				echo "[ /etc/pam.d/$item ]"
				echo "-------------------------------------------------------------------"
				cat /etc/pam.d/$item
				
				#faillock.so 존재 확인
				if grep -qi "pam_faillock.so" "/etc/pam.d/$item"; then
					typeFlag=2
				#pam_tally2.so 존재 확인
				elif grep -qi "pam_tally2.so" "/etc/pam.d/$item"; then
					typeFlag=3
				#pam_tally.so 존재 확인
				elif grep -qi "pam_tally.so" "/etc/pam.d/$item"; then
					typeFlag=4
				fi
				
				if [ $typeFlag -ne 2 ] || [ $typeFlag -ne 5 ] || [ $typeFlag -ne 4 ]; then
					statusPam=`expr $statusPam + 1`
				fi
				
			
				#pam_faillock.so 모듈 존재 시
				if [ $typeFlag -eq 2 ]; then
					i=`expr $i + 2`
					lineOne=$(grep -i "auth" /etc/pam.d/$item | grep -v "#" | grep -i "required" | grep -i "pam_faillock.so" | grep -i "deny")
					lineTwo=$(grep -i "auth" /etc/pam.d/$item | grep -v "#" | grep -i "default=die" | grep -i "pam_faillock.so" | grep -i "deny")
					lineThree=$(grep -i "account" /etc/pam.d/$item | grep -i "required" | grep -v "#" | grep -i "pam_faillock.so")
					
					if [ -z "$lineOne" ] || [ -z "$lineTwo" ] || [ -z "$lineThree" ]; then
						statusCode=`expr $statusCode + $i + 100`
						#pam 모듈 설정 값이 올바르지 않음
					else
						checkDeny1=$(echo "${lineOne}" | grep -oP 'deny\s*=\s*\K[0-9]+')
						checkDeny2=$(echo "${lineTwo}" | grep -oP 'deny\s*=\s*\K[0-9]+')
						# deny가 존재하지 않을 때 deny=3 값을 넣어줌(default가 3이므로)
						if [ -z "$checkDeny1" ]; then
							checkDeny1=3
						fi

						if [ -z "$checkDeny2" ]; then
							checkDeny2=3
						fi
						
						# deny 1 ~ 5
						if [ $checkDeny1 -gt 0 ] && [ $checkDeny2 -gt 0 ]; then
							statusCode=`expr $statusCode + $i`
						fi
					fi
				fi
				
				#pam_tally2.so 모듈 존재 시
				if [ $typeFlag -eq 3 ]; then
					i=`expr $i + 3`
					lineOne=$(grep -i "auth" /etc/pam.d/$item | grep -v "#" | grep -i "required" | grep -i "pam_tally2.so" | grep -i "deny")
					lineThree=$(grep -i "account" /etc/pam.d/$item | grep -i "required" | grep -v "#" | grep -i "pam_tally2.so")

					if [ -z "$lineOne" ] || [ -z "$lineThree" ]; then
						statusCode=`expr $statusCode + $i + 100`
					else
						checkDeny=$(echo "${lineOne}" | grep -oP 'deny\s*=\s*\K[0-9]+')
						# deny가 존재하지 않을 때 deny=3 값을 넣어줌(default가 3이므로)
						if [ -z "$checkDeny" ]; then
							checkDeny=3
						fi

						# deny 1 ~ 5
						if [ $checkDeny -gt 0 ]; then
							statusCode=`expr $statusCode + $i`
						fi
					fi
				fi
				
				#pam_tally.so 모듈 존재 시
				if [ $typeFlag -eq 4 ]; then
					i=`expr $i + 5`
					lineOne=$(grep -i "auth" /etc/pam.d/$item | grep -v "#" | grep -i "required" | grep -i "pam_tally.so" | grep -i "deny")
					lineThree=$(grep -i "account" /etc/pam.d/$item | grep -i "required" | grep -v "#" | grep -i "pam_tally.so")

					
					if [ -z "$lineOne" ] || [ -z "$lineThree" ]; then
						statusCode=`expr $statusCode + $i + 100`
					else
						checkDeny=$(echo "${lineOne}" | grep -oP 'deny\s*=\s*\K[0-9]+')
						# deny가 존재하지 않을 때 deny=3 값을 넣어줌(default가 3이므로)
						if [ -z "$checkDeny" ]; then
							checkDeny=3
						fi

						if [ $checkDeny -gt 0 ]; then
							statusCode=`expr $statusCode + $i`
						fi
						fi
					fi
					else
					echo "[ /etc/pam.d/$item ]"
					echo "FILE NOT FOUND"
					echo ""
					fileExist=`expr $fileExist + 2`
				fi
				typeFlag=0
				i=10
			done
	fi

	echo "-------------------------------------------------------------------"
	if [ $typeFlag -eq 1 ]; then
		if [ $statusCode -eq 1000 ]; then
			echo "[양호] faillock.conf 파일 내 deny 값이 설정되어 있음"
			RESULT="GOOD"
		elif [ $fileExist -eq 1 ]; then
			echo "[인터뷰] faillock.conf 파일이 존재하지 않음"
			RESULT="CHECK"
		else
			echo "[취약] faillock.conf 파일 내 deny 0으로 설정되어 있음"
			RESULT="BAD"
		fi
	else
		if [ $statusCode -eq 14 ] || [ $statusCode -eq 16 ] || [ $statusCode -eq 20 ]; then
			echo "[양호] system-auth 파일 및 password-auth 파일 내 deny 값이 설정되어 있음"
			RESULT="GOOD"
		elif [ $statusCode -gt 100 ] && [ $statusCode -lt 1000 ]; then
			echo "[취약] pam 모듈 설정 값이 올바르지 않거나 deny 옵션이 존재하지 않음"
			RESULT="BAD"
		elif [ $fileExist -ge 2 ]; then
			echo "[인터뷰] system-auth 파일 또는 password-auth 파일 존재하지 않음"
			RESULT="CHECK"
		elif [ $statusPam -ge 1 ]; then
			echo "[취약] pam_tally.so, pam_tally2.so, pam_faillock.so 모듈이 존재하지 않음"
			RESULT="BAD"
		else
			echo "[취약] deny 값이 0으로 설정되어 있음"
			RESULT="BAD"
		fi
	fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 
}
EOF


Unix_131(){ 
	{ 
		echo "양호: /etc/pam.d/su 파일에 auth required pam_wheel.so use_uid 라인이 존재하는 경우"
		echo "취약: /etc/pam.d/su 파일에 auth required pam_wheel.so use_uid 라인이 존재하지 않거나 주석 처리 되어 있는 경우"
	} > $STANDARD_FILE 
	 
	{

		#양호/취약 기준이 명확하게 제시되어 있으므로 해당 부분만 확인
		LB_CheckCase=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_BadCase=0
		
		echo "-------------------------------------------------------------------" 
		echo "[ su 명령어 pam 설정 (/etc/pam.d/su) ]" 
		if [ -f /etc/pam.d/su ]; then
			if [ `cat /etc/pam.d/su | awk -F"#" '{print $1}' | grep "pam_wheel.so" | grep "required" | grep "use_uid" | wc -l` -gt 0 ]; then  
				cat /etc/pam.d/su |awk -F"#" '{print $1}' | sed '/^$/d' | grep -i pam_wheel.so
			else
				echo "OPTION NOT FOUND"
				echo ""
				echo "[ su 파일 실행 권한 - ${SU_BIN} ]"
				if [ -f ${SU_BIN} ]; then
					if [ `ls -alL ${SU_BIN} | awk '{print $1}'  | grep '^-......---' | wc -l` -eq 0 ]; then 
						ls -ald ${SU_BIN}
						LB_BadCase=1
					else
						ls -ald ${SU_BIN}	
					fi
				else
					echo "${SU_BIN} FILE NOT FOUND" 
					LB_CheckCase=1
				fi		
			fi
		else 
			echo "/etc/pam.d/su FILE NOT FOUND" 
			LB_CheckCase=1
		fi 
		echo ""
		
		 
		echo "-------------------------------------------------------------------" 
		if [ "${LB_BadCase}" -gt 0 ]; then 
			echo "[취약] /etc/pam.d/su 파일 및 ${SU_BIN} 명령어 권한 설정이 적절하지 않음"
			RESULT="BAD"
		elif [ "${LB_CheckCase}" -gt 0 ]; then 
			echo "[확인] 설정파일 경로 확인 필요" 
			RESULT="CHECK" 
		else 
			echo "[양호] pam_wheel.so 모듈 설정으로 특정 그룹에 속한 사용자만 SU 명령어를 사용하도록 제한되어 있고 일반 사용자가 명령어를 사용할 수 없도록 권한 설정이 적절하게 되어 있음" 
			RESULT="GOOD" 
		fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

Unix_133(){
	{
		echo "양호: 1. cron.allow, cron.deny 파일 내부에 계정이 존재하는 경우"
		echo "2. cron.allow, cron.deny 파일 둘 다 없는 경우(root만 cron 사용 가능)"
		echo "취약: cron.allow 파일이 없고 cron.deny 파일에 내부에 계정이 없는 경우" 
	} > $STANDARD_FILE
	
	{ 	
		echo "-------------------------------------------------------------------"
		BADCASE=0
		FILEEXIST=0
		FILEEXIST2=0
		CONFIGEXIST=0
		echo "[ ${CRON_ALLOW} status ]"
		if [ -f ${CRON_ALLOW} ]; then
			FILEEXIST=1
			if [ `cat ${CRON_ALLOW} | awk -F"#" '{print $1}' | wc -w` -eq 0 ]; then
				echo "${CRON_ALLOW} contents NOT FOUND"
			else
				cat ${CRON_ALLOW}
				CONFIGEXIST=1
			fi
		else
			echo "${CRON_ALLOW} NOT FOUND"
		fi
		echo ""
		echo "[ ${CRON_DENY} status ]"
		if [ -f ${CRON_DENY} ]; then
			FILEEXIST2=1
			if [ `cat ${CRON_DENY} |  awk -F"#" '{print $1}' | wc -w` -eq 0 ]; then
				echo "${CRON_DENY} contents NOT FOUND"
			else
				cat ${CRON_DENY}
				CONFIGEXIST=1
			fi
		else
			echo "${CRON_DENY} NOT FOUND"
		fi
		
		echo "-------------------------------------------------------------------" 
		if [ ${FILEEXIST2} -gt 0 -a ${FILEEXIST} -eq 0 -a ${CONFIGEXIST} -eq 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		else
			echo "[양호] cron 사용 계정을 통제하고 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"	
		} > $STATUS_FILE 
}

Unix_142(){ 
	{ 
		echo "양호 : 동일한 UID로 설정된 사용자 계정이 존재하지 않는 경우"
		echo "취약 : 동일한 UID로 설정된 사용자 계정이 존재하는 경우"
	} > $STANDARD_FILE 
	 
	{ 
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------" 
		echo "[ UID ] " 
		if [ -f ${GS_PasswdConf} ]; then 
			cat ${GS_PasswdConf} | awk -F"#" '{print $1}' | grep -v '/bin/false' | grep -v '/sbin/nologin' | awk -F':' '{print $1 " : UID : " $3}' 
			for LS_Config in `cat ${GS_PasswdConf} | awk -F"#" '{print $1}' |grep -v '/bin/false' | grep -v '/sbin/nologin' | awk -F':' '{print $3}'` 
			do 
				if [ `cat ${GS_PasswdConf} | awk -F"#" '{print $1}' |grep -v '/bin/false' | grep -v '/sbin/nologin' | awk -F':' '$3=="'${LS_Config}'"' | wc -l` -ge 2 ]; then 
					LB_BadCase=1
				fi 
			done 
		else 
			echo "${GS_PasswdConf} FILE NOT FOUND"
			LB_CheckCase=1
		fi 
		 
		echo "-------------------------------------------------------------------" 
		if [ "${LB_BadCase}" -eq 1 ]; then 
			echo "[취약]"
			RESULT="BAD" 
		elif [ "${LB_CheckCase}" -eq 1 ]; then 
			echo "[확인] passwd 파일 확인 불가, 수동 점검 필요" 
			RESULT="CHECK" 
		else 
			echo "[양호] 동일한 UID를 사용하는 계정이 발견되지 않음" 
			RESULT="GOOD" 
		fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

Unix_144(){
	{
		echo "양호: dev에 대한 파일 점검 후 존재하지 않는 device 파일을 제거한 경우"
		echo "취약: dev에 대한 파일 미점검 또는 존재하지 않는 device 파일을 방치한 경우" 
	} > $STANDARD_FILE
	
	{
		if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then	
			LB_CheckCase=0

			echo "-------------------------------------------------------------------"
			LS_Files=`find /dev -type f -exec ls -l {} \; | grep -v '/dev/nul' | grep -v '/dev/rmt0' | grep -v "mqueue" | grep -v "shm"`
			echo "[ /dev Files ]"
			echo "${LS_Files}" | head -50
			if [ `echo "${LS_Files}" | wc -w` -gt 0 ]; then
				LB_CheckCase=1
			else
				echo "FILE NOT FOUND"
			fi
			echo ""

			echo "-------------------------------------------------------------------"
				if [ "${LB_CheckCase}" -gt 0 ]; then
					echo "[확인] 현황의 파일 중 존재하지 않는 device 파일이 있는지 담당자와 인터뷰 필요"
					RESULT="CHECK"
				else
					echo "[양호] /dev 경로에 존재하지 않는 device 파일이 없음"
					RESULT="GOOD"
				fi
			echo "-------------------------------------------------------------------"	
		elif [ `echo $FIND_CHECK | grep -i "2" | wc -l` -gt 0 ]; then
			echo "-------------------------------------------------------------------"
			echo "-------------------------------------------------------------------"
			echo "[확인] /dev 경로에 파일이 존재하는지, 존재한다면 필요한지 여부 담당자와의 인터뷰 필요"
			echo "(find /dev -type f -exec ls -l {} \; | grep -v '/dev/nul' | grep -v '/dev/rmt0' 명령어를 사용하여 출력된 파일 중 불필요한 파일 확인)"
			RESULT="CHECK"
			echo "-------------------------------------------------------------------"
		fi		
	} > $STATUS_FILE
}

Unix_147(){
	{
		echo "양호: SNMP 서비스를 사용하지 않는 경우"
		echo "취약: 불필요하게 SNMP 서비스를 사용하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER snmpd
		
		if [ ${PCK} -eq 1 ]; then
			LB_BadCase=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ SNMP ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ SNMP ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ SNMP ]"
			echo "SNMP SERVICE NOT ACTIVATE"
			echo ""
		fi
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] SNMP 서비스 활성화"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] SNMP 서비스 활성화, 필요에 의한 사용인지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] SNMP 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_148(){
	{
		echo "양호: ServerTokens Prod, ServerSignature Off로 설정되어있는 경우"
		echo "취약: ServerTokens Prod, ServerSignature Off로 설정되어있지 않은 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		if [ `echo $Running_WebService | grep -i "1" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Apache 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "2" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Webtob 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "3" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] OHS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "4" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Nginx 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "5" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] JEUS 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "6" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] Tomcat 서비스 구동 중이므로 ${ResultFile_Name} 파일 확인"
		elif [ `echo $Running_WebService | grep -i "^0" | wc -l` -gt 0 ]; then
			RESULT="CHECK"
			echo "[확인] RAWDATA 내 PCK()로 웹 서비스 구동 여부 확인 필요"
		fi 
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_158(){
	{
		echo "양호: Telnet 서비스가 비활성화 되어 있는 경우"
		echo "취약: Telnet 서비스가 불필요하게 활성화 되어 있는 경우"
	} > $STANDARD_FILE
	
	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "telnet" "telnet.socket"
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ Telnet ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ Telnet ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ Telnet ]"
			echo "Telnet SERVICE NOT ACTIVATE"
			echo ""
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] Telnet 서비스가 불필요하게 활성화 되어 있는지 담당자와의 인터뷰"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
	        RESULT="CHECK"
		else
			echo "[양호] Telnet 서비스가 비활성화 되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_161(){
	{
		echo "양호 : ftpusers 파일의 소유자가 root이고 권한이 640 이하인 경우" 
		echo "취약 : ftpusers 파일의 소유자가 root가 아니거나 권한이 640 이하가 아닌 경우"
	}  > $STANDARD_FILE 
	{	
		LI_ConfExist=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LI_FileExist=0
		LB_GoodCase=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "ftp"
		LS_Result=`PROCESS_CHECKER "ftp"` 
		if [ ${PCK} -eq 1 ]; then
			if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
				echo "[ ftpusers ]"
				for LS_File1 in ${GS_VsFTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						ls -alL ${LS_File1}
						echo ""
						if [ `ls -alL ${LS_File1} | grep '^...-.-----' | wc -l` -eq 0 -o `ls -alL ${LS_File1} | awk '{print $3}' | grep -i "root" | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
					fi
				done

				if [ ${LI_FileExist} -eq 0 ]; then
					LB_BadCase=1 
					echo "ftpusers FILE NOT FOUND"
					echo ""
				fi

			elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then
				echo "[ ftpusers ]"
				for LS_File1 in ${GS_ProFTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						ls -alL ${LS_File1}
						echo ""
						if [ `ls -alL ${LS_File1} | grep '^...-.-----' | wc -l` -eq 0 -o `ls -alL ${LS_File1} | awk '{print $3}' | grep -i "root" | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
					fi
				done

				if [ ${LI_FileExist} -eq 0 ]; then
					LB_BadCase=1 
					echo "ftpusers FILE NOT FOUND"
					echo ""
				fi

			else 
				echo "[ ftpusers ]"
				for LS_File1 in ${GS_FTPUsersConf}; do
					if [ -f ${LS_File1} ]; then
						LI_FileExist=1
						ls -alL ${LS_File1}
						echo ""
						if [ `ls -alL ${LS_File1} | grep '^...-.-----' | wc -l` -eq 0 -o `ls -alL ${LS_File1} | awk '{print $3}' | grep -i "root" | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
					fi
				done

				if [ ${LI_FileExist} -eq 0 ]; then
					LB_BadCase=1 
					echo "ftpusers FILE NOT FOUND"
					echo ""
				fi
			fi
			
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase1=1
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp SERVICE NOT FOUND"
			echo ""
			LB_GoodCase=1
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LB_CheckCase1}" -eq 1 ]; then 
			echo "[확인] inetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ "${LB_CheckCase2}" -eq 1 ]; then 
			echo "[확인] xinetd 설정파일이 존재하지 않아, 담당자와 인터뷰가 필요함"
			RESULT="CHECK"
		elif [ "${LB_GoodCase}" -eq 1 ]; then
			echo "[양호] FTP 서비스 사용 안함"
			RESULT="GOOD"
		elif [ "${LB_GoodCase1}" -eq 1 ]; then
			echo "[양호] ftpusers 파일이 존재하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] ftpusers 파일의 소유자가 root이고 권한이 640 이하 설정"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_163(){ 
	{ 
		echo "양호: /etc/motd, /etc/issue.net, /etc/ssh/sshd_config 파일 설정 등으로 시스템 사용 주의사항을 출력하는 경우"  
		echo "취약: /etc/motd, /etc/issue.net, /etc/ssh/sshd_config 파일 설정 등으로 시스템 사용 주의사항 미출력 시 또는 표시 문구 내에 시스템 버전 정보가 노출되는 경우"  
	} > $STANDARD_FILE 
 
	{ 
	LI_FileExist=0
	LI_FileExist1=0
	LI_ConfigExist=0
	LI_ConfigExist1=0
	LB_CheckCase1=0
	LB_CheckCase2=0
	LB_CheckCase3=0
	LB_BadCase=0

	echo "-------------------------------------------------------------------"
	echo "[ /etc/motd ]"
	if [ -f /etc/motd ]; then
		if [ `cat /etc/motd | wc -w` -gt 0 ]; then
			cat /etc/motd | awk -F"#" '{print $1}' | sed '/^$/d'
			if [ `cat /etc/motd | grep "[0-9]\.[0-9]" | wc -l` -gt 0 -o `cat /etc/motd | grep -i "verison" | grep "[0-9]" | wc -l` -gt 0 -o `cat /etc/motd | grep -i "release" | grep "[0-9]" | wc -l` -gt 0 ]; then
				LB_BadCase=1
			fi
		else
			LB_BadCase=1
			echo "LOGIN MESSAGE NOT FOUND"
		fi
	else
		LB_BadCase=1
		echo "/etc/motd FILE NOT FOUND"
	fi
	echo ""
	echo "[ /etc/issue ]"
	if [ -f /etc/issue ]; then
		LS_Config=`cat /etc/issue | awk -F"#" '{print $1}' | sed '/^$/d'`
		if [ `echo "${LS_Config}" | wc -w` -gt 0 ]; then
			echo "${LS_Config}"
			
			if [ `echo "${LS_Config}" | grep "[0-9]\.[0-9]" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep -i "release" | grep "[0-9]" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep -i "version" | grep "[0-9]" | wc -l` -gt 0 ]; then
				LB_BadCase=1
			elif [ `echo "${LS_Config}" | grep "[\\]S" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep "[\\]r" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep "[\\]m" | wc -l` -gt 0 ]; then
				LB_BadCase=1
			fi
		else
			LB_BadCase=1
			echo "LOGIN MESSAGE NOT FOUND"
		fi
	else
		LB_BadCase=1
		echo "/etc/motd FILE NOT FOUND"
	fi
	echo ""
	PROCESS_CHECKER "telnet" "telnet.socket"
	if [ `echo $PCK` -gt 0 ]; then  
		echo "[ /etc/issue.net ]"
		if [ -f /etc/issue.net ]; then
			LS_Config=`cat /etc/issue.net | awk -F"#" '{print $1}' | sed '/^$/d'`
			if [ `echo "${LS_Config}" | wc -w` -gt 0 ]; then
				echo "${LS_Config}"
				echo ""
				if [ `echo "${LS_Config}" | grep "[0-9]\.[0-9]" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep -i "release" | grep "[0-9]" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep -i "version" | grep "[0-9]" | wc -l` -gt 0 ]; then
					LB_BadCase=1
				elif [ `echo "${LS_Config}" | grep "[\\]S" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep "[\\]r" | wc -l` -gt 0 -o `echo "${LS_Config}" | grep "[\\]m" | wc -l` -gt 0 ]; then
					LB_BadCase=1
				fi
			else
				LB_BadCase=1
				echo "LOGIN MESSAGE NOT FOUND"
				echo ""
			fi
		else
			LB_BadCase=1
			echo "/etc/motd FILE NOT FOUND"
			echo ""
		fi
	elif [ ${INETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase1=1
		echo "[ telnet ]"
		echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
		echo ""
	elif [ ${XINETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase2=1
		echo "[ telnet ]"
		echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
		echo ""
	else
		echo "[ telnet ]"
		echo "telnet SERVICE NOT FOUND"
		echo ""
	fi

	PROCESS_CHECKER "sshd"
	if [ `echo $PCK` -gt 0 ]; then  
		for LS_File in ${GS_SSHDConf}; do
			if [ -f ${LS_File} ]; then
				LI_FileExist=1
				echo ""
				echo "[ sshd config (${LS_File}) ]"
				if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep 'Banner' | awk '{print $2}' | wc -w` -gt 0 ]; then
					cat ${LS_File} | awk -F"#" '{print $1}' | grep "Banner"
					LI_ConfigExist=1
					echo ""
					LS_Files1=`cat ${LS_File} | awk -F"#" '{print $1}' | grep 'Banner' | awk '{print $2}'`
					for LS_File1 in ${LS_Files1}; do
						echo "[ sshd Banner (${LS_File1}) ]"
						if [ -f ${LS_File1} ]; then
							LI_FileExist1=1
							if [ `cat ${LS_File1} | wc -w` -gt 0 ]; then
								LI_ConfigExist1=1
								cat ${LS_File1} | awk -F"#" '{print $1}' | sed '/^$/d'
								echo ""
								if [ `cat ${LS_File1} | grep "[0-9]\.[0-9]" | wc -l` -gt 0 -o `cat /etc/motd | grep -i "verison" | grep "[0-9]" | wc -l` -gt 0 -o `cat /etc/motd | grep -i "release" | grep "[0-9]" | wc -l` -gt 0 ]; then
									LB_BadCase=1
								fi
							else
								echo "This File is Empty"
								echo ""
								LB_BadCase=1
							fi
						else
							echo "File NOT FOUND"
							echo ""
						fi
					done

					if [ ${LI_FileExist1} -eq 0 ]; then
						LB_BadCase=1
					fi

					if [ ${LI_ConfigExist1} -eq 0 ]; then
						LB_BadCase=1
					fi

				else
					LB_BadCase=1
					echo "Option NOT FOUND"
					echo ""
				fi
			fi
		done
	elif [ ${INETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase1=1
		echo "[ sshd ]"
		echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
		echo ""
	elif [ ${XINETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase2=1
		echo "[ sshd ]"
		echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
		echo ""
	else
		echo "[ sshd ]"
		echo "sshd SERVICE NOT FOUND"
		echo ""
	fi

	if [ ${LI_FileExist} -eq 0 -a ${PCK} -gt 0 ]; then
		echo "[ Config File : "`echo ${GS_SSHDConf} | tr " " ", "`" ]"
		echo "ssh config FILE NOT FOUND"
		echo ""
		LB_CheckCase3=1
	fi
	echo "-------------------------------------------------------------------"
	if [ ${LB_BadCase} -gt 0 ]; then
		echo "[취약]"
		RESULT="BAD"
	elif [ ${LB_CheckCase1} -gt 0 ]; then
		echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_CheckCase2} -eq 1 ]; then
		echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		RESULT="CHECK"
	elif [ ${LB_CheckCase3} -eq 1 ]; then
		echo "[확인] SSHD 설정 파일을 찾을 수 없어"
		RESULT="CHECK"
	else
		echo "[확인] 현황에 출력된 로그인 메시지가 경고 메시지인지 확인"
		RESULT="CHECK"
	fi
	echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

Unix_164(){
	{
		echo "양호 : 구성원이 존재하지 않는 GID가 존재하지 않는 경우"
		echo "취약 : 구성원이 존재하지 않는 GID가 존재하는 경우"
	} > $STANDARD_FILE
	
	{
	echo "-------------------------------------------------------------------"
	if [ -f /etc/group ]; then
		if [ ${GS_OSVersion} -eq 6 ]; then
			LS_GroupConf=`cat /etc/group | awk -F"#" '{print $1}' | awk -F":" '{if ($3 >= 500) print $0}'`
		else
			LS_GroupConf=`cat /etc/group | awk -F"#" '{print $1}' |awk -F":" '{if ($3 >= 1000) print $0}' `
		fi
		if [ -f /etc/passwd ]; then
			if [ ${GS_OSVersion} -eq 6 ]; then
				LI_PasswdConf=`cat /etc/passwd | awk -F"#" '{print $1}' | awk -F":" '{if ($4 >= 500) print $4}'`
			else
				LI_PasswdConf=`cat /etc/passwd | awk -F"#" '{print $1}' | awk -F":" '{if ($4 >= 1000) print $4}'`
			fi
			LB_BadCase=0
			LB_CheckCase=0
			LI_ConfigExist=0
			if [ ${GS_OSVersion} -eq 6 ]; then
				echo "[ /etc/group bad group(UID 500 up) ]"
			else
				echo "[ /etc/group bad group(UID 1000 up) ]"
			fi
			for LI_GID in ${LS_GroupConf}; do
				if [ ${GS_OSVersion} -eq 6 ]; then
		        	LA_Tmp=`echo "${LI_GID}" | awk -F":" '{if ($3 >= 500) print $3}'`
		        else
		        	LA_Tmp=`echo "${LI_GID}" | awk -F":" '{if ($3 >= 1000) print $3}'`
		        fi
		        
		        if [ `echo "${LI_PasswdConf}" | grep -w "${LA_Tmp}" | wc -l` -eq 0 ]; then
		        	LI_ConfigExist=1
		        	LA_Tmp=`echo "${LI_GID}" | awk -F":" '{print $4}' | tr "," " "`
		        	if [ `echo ${LA_Tmp} | wc -w` -gt 0 ]; then
		        		for LS_User in ${LA_Tmp}; do
		        			if [ ${GS_OSVersion} -eq 6 ]; then
			        			if [ `cat /etc/passwd | awk -F":" '{if ($3 >= 500) print $1}' | grep -w "${LS_User}" | wc -w` -eq 0 ]; then
		        					LB_BadCase=1
		        					echo "${LI_GID}"
		        				fi
		        			else
		        				if [ `cat /etc/passwd | awk -F":" '{if ($3 >= 1000) print $1}' | grep -w "${LS_User}" | wc -w` -eq 0 ]; then
		        					LB_BadCase=1
		        					echo "${LI_GID}"
		        				fi
		        			fi
		        		done
		        	else
			            echo "${LI_GID}"
			            LB_BadCase=1
		        	fi
		        fi
			done
		
			if [ ${LI_ConfigExist} -eq 0 ]; then
			        echo "no bad group"
			else
				echo ""
				echo "Check /etc/passwd, /etc/group file"
				echo ""
			fi
			 
		else
			echo "/etc/passwd FILE NOT FOUND" 
			LB_CheckCase=1
		fi
	else
		LB_CheckCase=1
		echo "/etc/shadow FILE NOT FOUND"
	fi

	echo "-------------------------------------------------------------------"
	if [ "${LB_BadCase}" -gt 0 ]; then
		echo "[취약]"
		RESULT="BAD"
	elif [ "${LB_CheckCase}" -gt 0 ]; then
		echo "[확인] 설정 파일이 존재하지 않음"
		RESULT="CHECK"
	else
		echo "[양호] 시스템에 불필요한 그룹이 존재하지 않음"
		RESULT="GOOD"
	fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_165(){
	{
		echo "양호: 로그인이 필요하지 않은 계정에 /bin/false(/sbin/nologin) 쉘이 부여되어 있는 경우"
		echo "취약: 로그인이 필요하지 않은 계정에 /bin/false(/sbin/nologin) 쉘이 부여되지 않는 경우"    
	} > $STANDARD_FILE

	{
	LB_BadCase=0
	LB_CheckCase1=0
	LB_CheckCase2=0

    #LS_BadAccount="^daemon\|^bin\|^sys\|^adm\|^listen\|^nobody\|^nobody4\|^noaccess\|^diag\|^operator\|^games\|^gopher"
	echo "-------------------------------------------------------------------"
	echo ""
	echo "[ ${GS_PasswdConf} ]"
	if [ -f ${GS_PasswdConf} ]; then
		cat ${GS_PasswdConf} | awk -F"#" '{print $1}' | grep -v "/sbin/nologin\|/bin/false"

	#	if [ `cat ${GS_PasswdConf} | awk -F"#" '{print $1}' | grep "${LS_BadAccount}" | grep -v "admin" | awk -F":" '{print $7}' | grep "bin/sh\|csh\|bash\|ksh" | wc -l` -gt 0 ]; then
	#		LB_BadCase=1
	#	else
		LB_CheckCase1=1
	#	fi
	else
		LB_CheckCase2=1
		echo "${GS_PasswdConf} FILE NOT FOUND"
	fi
	echo ""
	
	echo "-------------------------------------------------------------------"
		#if [ "${LB_BadCase}" -gt 0 ]; then
		#		echo "[취약]"
		#		RESULT="BAD"
		if [ "${LB_CheckCase1}" -gt 0 ]; then
				echo "[확인] 현황의 계정 중 로그인이 필요하지 않은 계정에 쉘이 부여되어 있는지 담당자의 인터뷰가 필요함"
				RESULT="CHECK"
		elif [ "${LB_CheckCase2}" -gt 0 ]; then
				echo "[확인] ${GS_PasswdConf} 파일이 존재하지 않음"
				RESULT="CHECK"
		fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_166(){
	{
		echo "양호: 불필요하거나 의심스러운 숨겨진 파일 및 디렉터리를 삭제한 경우" 
		echo "취약: 불필요하거나 의심스러운 숨겨진 파일 및 디렉터리를 방치한 경우"   
	} > $STANDARD_FILE
	
	{
		if [ `echo $FIND_CHECK | grep -i "1" | wc -l` -gt 0 ]; then
			LB_CheckCase=0
			echo "-------------------------------------------------------------------"
			for HOME in ${FIND_HOMEDIR_SORT}; do
				if [ $HOME != "/" -a $HOME != "/root" -a -d $HOME ]; then
					badfiles=`find $HOME -type f -name ".*" -exec ls -l {} \; 2>/dev/null` 
					if [ `echo $badfiles | wc -w` -gt 0 ]; then
						echo "[ $HOME hidden file]"
						echo "$badfiles"
						LB_CheckCase=1
						echo ""
					fi
				
					baddirs=`find $HOME -type d -name ".*" -exec ls -l {} \; 2>/dev/null`
					if [ `echo $baddirs | wc -w` -gt 0 ]; then
						echo "[ $HOME hidden dir]"
						echo "$baddirs"
						LB_CheckCase=1
						echo ""
					fi
				fi
			
			done
		
			if [ "${LB_CheckCase}" -eq 0 ]; then
				echo "hidden file/dir NOT FOUND"
			fi
			echo "-------------------------------------------------------------------"
			if [ "${LB_CheckCase}" -gt 0 ]; then
				echo "[인터뷰] 현황에 출력된 숨겨진 파일 및 디렉터리가 불필요한지 담당자와 인터뷰가 필요함"
				RESULT="CHECK"
			else
				echo "[양호] 숨겨진 파일 및 디렉터리가 존재하지 않음"
				RESULT="GOOD"
			fi
			echo "-------------------------------------------------------------------"
		elif [ `echo $FIND_CHECK | grep -i "2" | wc -l` -gt 0 ]; then
			echo "-------------------------------------------------------------------"
			echo "-------------------------------------------------------------------"
			echo "[확인] 숨겨진 파일 및 디렉터리가 존재하는지, 존재한다면 필요한지 여부 담당자와 인터뷰 필요"
			echo "(find [각 계정의 홈 디렉터리] -type f -name \".*\" -exec ls -l {} \; 2>/dev/null 명령어 사용하여 숨김 파일 확인)"
			RESULT="CHECK"
			echo "-------------------------------------------------------------------"
		fi
	} > $STATUS_FILE
}

Unix_170() {
	{
		echo "양호: SMTP 접속 배너에 노출되는 정보가 없는 경우"
		echo -e "취약: SMTP 접속 배너에 노출되는 정보가 있는 경우 \n※ 정보 노출: 서비스명 + 버전 정보가 노출되는 경우 취약"
	} > $STANDARD_FILE
		
	{
		LB_BadCase=0
		LB_GoodCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0

		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail		
		echo ""
		if [ ${PCK} -eq 1 ]; then
			echo "[ SMTP Sendmail Login Message ]" 
			if [ -f /etc/mail/sendmail.cf ]; then 
				if [ `cat /etc/mail/sendmail.cf | grep -i "SMTPGreetingMessage" | grep -v '^#' | wc -l` -gt 0 ]; then 
					cat /etc/mail/sendmail.cf | grep -i "SMTPGreetingMessage" 
					LB_CheckCase4=1
				else
					echo "SMTPGreetingMessage NOT FOUND"
				fi 
			else 
				echo "/etc/mail/sendmail.cf FILE NOT FOUND" 
				LB_CheckCase1=1
			fi 
		
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			LB_CheckCase2=1
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			LB_CheckCase3=1
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT FOUND"
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi
		echo ""

		PROCESS_CHECKER postfix
		if [ ${PCK} -eq 1 ]; then	
			echo "[ SMTP Postfix Login Message ]"
			if [ -f /etc/postfix/main.cf ]; then
				if [ `cat /etc/postfix/main.cf | grep -v '^#' | grep -i "smtpd_banner" | wc -l` -gt 0 ]; then 
					cat /etc/postfix/main.cf| grep -i "smtpd_banner"
					LB_CheckCase4=1
				else
					echo "smtpd_banner NOT FOUND"
					echo ""
				fi
			else 
				echo "/etc/postfix/main.cf FILE NOT FOUND" 
				echo ""
				LB_CheckCase1=1
			fi

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ postfix ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			LB_CheckCase2=1
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ postfix ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			LB_CheckCase3=1
			echo ""
		else
			echo "[ postfix ]"
			echo "postfix SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=`expr ${LB_GoodCase} + 1`
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] Config 파일 설정 내 확인 후 수동 점검 필요"
			RESULT="CHECK"	
		elif [ ${LB_GoodCase} -eq 3 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] SMTP 서비스 배너에 정보가 노출되지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------" 
	
   } > $STATUS_FILE
}

Unix_171() {
	{
		echo "양호: FTP 접속 배너에 노출되는 정보가 없는 경우"
		echo "취약: FTP 접속 배너에 노출되는 정보가 있는 경우"
	} > $STANDARD_FILE
		
	{		
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER ftp
		LS_Result=`PROCESS_CHECKER ftp` 
		if [ ${PCK} -eq 1 ]; then
			if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
				for LS_File1 in ${GS_VsFTPConf}; do
					echo "[ vsFTP Login Message ]" 
					if [ -f ${LS_File1} ];then 
						LI_FileExist1=1
						if [ `cat ${LS_File1} | grep -i 'ftpd_banner' | grep -v '^#' | wc -l` -gt 0 ]; then 
							echo "${LS_File1} : " 
							cat ${LS_File1} | grep -i 'ftpd_banner' 
							echo "" 
						else
							echo "${LS_File1} : ftpd_banner OPTIONS NOT FOUND"
						fi 
						
					else
						echo "${LS_File1} NOT FOUND"
					fi 
				done 

				if [ ${LI_FileExist1} -eq 0 ]; then
					echo "vsFTP FILE NOT FOUND"
					echo ""
				fi

			elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then 
				for LS_File2 in ${GS_ProFTPConf}; do
					echo "[ proFTP Login Message ]" 
					if [ -f ${LS_File2} ];then 
						LI_FileExist2=1					
						if [ `cat ${LS_File2} | grep -i 'ServerIdent' | grep -v '^#' | grep -i 'on' | wc -l` -gt 0 ]; then 
							echo "${LS_File2} : " 
							cat ${LS_File2} | grep -i 'ServerIdent' 
							echo "" 
						else
							echo "${LS_File2} : ServerIdent OPTIONS NOT FOUND"
						fi 
					fi 
				done 
				if [ ${LI_FileExist2} -eq 0 ]; then
					echo "proFTP FILE NOT FOUND"
					echo ""
				fi

			else 
				echo "[ /etc/ftpaccess Login Message ]" 
				if [ -f /etc/ftpaccess ]; then 
					if [ `cat /etc/ftpaccess | grep -i "greeting" | grep -i "full" | grep -v '^#' | wc -l` -gt 0 ]; then 
						echo "/etc/ftpaccess : " 
						cat /etc/ftpaccess | grep -i 'greeting' 
						echo "" 
					else 
						cat /etc/ftpaccess | grep -i 'greeting' 
						echo " greeting NOT FOUND"
					fi
				elif [ -f /etc/ftpd/ftpaccess ]; then
					if [ `cat /etc/ftpd/ftpaccess | grep -i "greeting" | grep -i "full" | grep -v '^#' | wc -l` -gt 0 ]; then 
						echo "/etc/ftpd/ftpaccess : " 
						cat /etc/ftpd/ftpaccess | grep -i 'greeting' 
						echo "" 
					else 
						cat /etc/ftpd/ftpaccess | grep -i 'greeting' 
						echo " greeting NOT FOUND"
					fi
				else 
					echo "/etc/ftpaccess FILE NOT FOUND" 
				fi 
			fi

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp service not found"
			echo ""
		fi
		

		echo "-------------------------------------------------------------------"
			echo "[확인] 설정 파일 확인 후 수동 점검" 
			RESULT="CHECK" 
		echo "-------------------------------------------------------------------" 
      
   } > $STATUS_FILE
}


Unix_173(){
	{
		echo "양호: DNS 서비스의 동적 업데이트 기능이 비활성화 되었거나, 활성화 시 적절한 접근통제를 수행하고 있을 경우"
		echo "취약: DNS 서비스의 동적 업데이트 기능이 불필요하게 활성화 되어있거나, 필요에 의해 사용 중이어도 적절한 접근통제를 수행하고 있지 않을 경우"
	} > $STANDARD_FILE
		
	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_BadCase=0
		LB_GoodCase=0
		LI_FileExist=0

		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER "named"

		if [ ${PCK} -eq 1 ]; then
			for LS_File in ${GS_DNSConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					echo "[ ${LS_File} update-policy ]"
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | awk '/update-policy/,/}/' | grep -i "any" | wc -l` -gt 0 ]; then #any 존재
						cat ${LS_File} | awk -F"#" '{print $1}' | awk '/update-policy/,/}/'
						echo ""
						LB_BadCase=1
					else
						LB_GoodCase=1
						cat ${LS_File} | awk -F"#" '{print $1}' | awk '/update-policy/,/}/'
						echo "'any' Not Found"
					fi

					echo "[ ${LS_File} allow-update ]"
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | awk '/allow-update/,/}/' | grep -i "any" | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | awk '/allow-update/,/}/'
						echo ""
						LB_BadCase=1
					else
						LB_GoodCase=`expr $LB_GoodCase + 1`
						cat ${LS_File} | awk -F"#" '{print $1}' | awk '/update-policy/,/}/'
						echo "'any' Not Found"
					fi
				fi
			done
			if [ ${LI_FileExist} -eq 1 ]; then
				echo "${LS_File} FILE NOT FOUND" 
				LB_CheckCase1=1
			fi

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo "DNS SERVICE NOT ACTIVATE"
			echo ""
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] 동적 업데이트 설정에 'any' 값이 존재하고 있음"
			RESULT="BAD"
		elif [ ${LB_GoodCase} -eq 2 ]; then
			echo "[양호] 동적 업데이트 설정에 'any' 값이 존재하지 않음"
			RESULT="GOOD"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] DNS 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_174() {
	{
		echo "양호: DNS 서비스가 실행 중이지 않거나, 필요에 의해 사용 중인 경우"
		echo "취약: DNS 서비스가 불필요하게 실행 중인 경우"
	} > $STANDARD_FILE
		
	{
      LB_CheckCase1=0
      LB_CheckCase2=0
      LB_CheckCase3=0

      echo "-------------------------------------------------------------------"
      
      PROCESS_CHECKER named

      if [ ${PCK} -eq 1 ]; then
         LB_CheckCase1=1
      elif [ ${INETD_CONFGCK} -eq 2 ]; then
         LB_CheckCase2=1
         echo "[ named ]"
         echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
         echo ""
      elif [ ${XINETD_CONFGCK} -eq 2 ]; then
         LB_CheckCase3=1
         echo "[ named ]"
         echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
         echo ""
      else
         echo "[ named ]"
         echo "DNS SERVICE NOT ACTIVATE"
         echo ""
      fi

      echo "-------------------------------------------------------------------"
      if [ ${LB_CheckCase1} -eq 1 ]; then
         echo "[확인] DNS 서비스가 구동중, 불필요한 서비스인지 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      elif [ ${LB_CheckCase2} -eq 1 ]; then
         echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      elif [ ${LB_CheckCase3} -eq 1 ]; then
         echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         RESULT="CHECK"
      else
         echo "[양호] DNS 서비스가 구동중이지 않음"
         RESULT="GOOD"
      fi
      echo "-------------------------------------------------------------------"
      
   } > $STATUS_FILE
}


Unix_175() { 
	{ 
		echo "양호: NTP 서버 동기화가 설정되어 있는 경우" 
		echo "취약: NTP 서버 동기화가 미설정되어 있는 경우" 
	} > $STANDARD_FILE 
		 
	{ 
		LB_badCase=0
		LB_goodCase=0
		daemonExist=0
        echo "-------------------------------------------------------------------"
		if ps -ef | grep -v grep | grep "ntpd" > /dev/null; then
			echo "[ NTP daemon ]"
			ps -ef | grep -v grep | grep "ntpd"
			echo "-------------------------------------------------------------------"
	
			# 동기화된 서버 확인
			if ntpq -pn | grep -q "^\*" > /dev/null; then
				echo "[ NTP Server Sync ]"
				echo ""
				ntpq -pn
				LB_goodCase=$((LB_goodCase+1))
				echo ""
				# date 명령어
				echo "[Time]"
				date "+%Y-%m-%d %T"
				echo ""
				echo "-------------------------------------------------------------------"
			else
				echo "[ NTP Server Sync ]"
				echo ""
				ntpq -pn
				LB_badCase=1
				echo ""
				# date 명령어
				echo "[Time]"
				date "+%Y-%m-%d %T"
				echo "" 
				echo "-------------------------------------------------------------------"
			fi
		else
			echo "ntpd Daedmon NOT Running" 
			daemonExist=$((deamonExist + 1))
		fi

		# chrony
		if ps -ef | grep -v grep | grep "chronyd" > /dev/null; then
			echo "[ Chrony daemon ]"
			echo ""
			ps -ef | grep -v grep | grep "chronyd"
			echo "-------------------------------------------------------------------"
			
			# 동기화 여부 확인
			if chronyc tracking | grep -i "Leap status" | grep -i "Not synchronised"; then
				echo "[ Chrony Server Sync ]"
				while read -r line; do
					echo "$line"
				done <<< "$(chronyc tracking)"
				LB_badCase=$((LB_badCase+1))
				echo ""
				# date 명령어
				echo "[Time]"
				date "+%Y-%m-%d %T"
			else
				echo "[ Chrony Server Sync ]"
				while read -r line; do
					echo "$line"
				done <<< "$(chronyc tracking)"
				LB_goodCase=$((LB_goodCase+1))
				echo ""
				# date 명령어
				echo "[Time]"
				date "+%Y-%m-%d %T"
				echo "-------------------------------------------------------------------"
			fi
		else
			echo "chronyd Daedmon NOT Running"
			daemonExist=$((deamonExist + 1))
		fi

        echo "-------------------------------------------------------------------"
        if [ $LB_badCase -ge 1 ]; then
            echo "[취약] NTP 서버 설정 및 동기화가 되어 있지 않음"
            RESULT="BAD"
        elif [ $LB_goodCase -ge 1 ]; then
            echo "[양호] NTP 서버 설정 및 동기화가 되어 있음"
            RESULT="GOOD"
		elif [ $deamonExist -ge 2 ]; then
			echo "[취약] NTP, Chrony 데몬이 동작하지 않음"
			RESULT="BAD"
        fi
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 


Unix_176(){

	{
		echo ""
	} > $STANDARD_FILE

	LB_BadCase=0
	LB_GoodCase=0
	LB_CheckCase1=0
	LB_CheckCase2=0
	LB_CheckCase3=0
	LI_FileExist=0

	echo "-------------------------------------------------------------------"
	PROCESS_CHECKER snmpd
	
	if [ "${PCK}" -gt 0 ]; then
			
		if [ $(snmpd -v | awk '/NET-SNMP version/{print $3}') \< 4.0.0 ]; then
			echo "-------------------------------------------------------------------"
			echo "[ NET-SNMP VERSION : $(snmpd -v 2>&1 | awk '/NET-SNMP/{print $3}') ]"
			echo "-------------------------------------------------------------------"
			echo ""
			LB_BadCase=1 # 4.0 미만일 경우
		else

			echo "-------------------------------------------------------------------"
			echo "[ NET-SNMP VERSION : $(snmpd -v 2>&1 | awk '/NET-SNMP/{print $3}') ]"
			echo "-------------------------------------------------------------------"
			echo ""
			
			# snmp 설정 확인
			if [ -e "/etc/snmp/snmpd.conf" ]; then
				# snmpv1, snmpv2c 확인
				snmpv1=$(grep -i "group" /etc/snmp/snmpd.conf | grep -i "v1" | grep -v "^#")
				snmpv2c=$(grep -i "group" /etc/snmp/snmpd.conf | grep -i "v2c" | grep -v "^#")
				snmpv3_1=$(egrep -i "rouser|rwuser" /etc/snmp/snmpd.conf | grep -v "^#")
				
				snmp_rorw=$(egrep -i 'rocommunity|rwcommunity' /etc/snmp/snmpd.conf | grep -v '^#')
				snmp_com=$(grep -i "com2sec" /etc/snmp/snmpd.conf | grep -v "^#")
				
				echo "[ /etc/snmp/snmpd.conf ]"
				if ([ -z "$snmpv1" ] && [ -z "$snmpv2c" ]) && [ -z "$snmp_rorw" ] || [ -z "$snmp_com" ]; then
					echo "SNMPv1, SNMPv2c OPTION NOT FOUND"
					if [ -n "$snmpv3_1" ]; then
						# v3 사용
						echo "[ SNMPv3 ]"
						echo $snmpv3_1
						echo ""
						LB_GoodCase=2
					else
						echo "SNMPv3 OPTION NOT FOUND"
						echo ""
						LB_BadCase=1
					fi
				else
					echo $snmpv1
					echo $snmpv2c
					echo $snmp_rorw
					echo $snmp_com
					LB_BadCase=1
					echo ""
				fi
						
			else
				echo "/etc/snmp/snmpd.conf NOT FOUND"
				LB_CheckCase1=1
			fi
		fi
	
	elif [ ${INETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase2=1
		echo "[ SNMP ]"
		echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
		echo ""
	elif [ ${XINETD_CONFGCK} -eq 2 ]; then
		LB_CheckCase3=1
		echo "[ SNMP ]"
		echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
		echo ""
	else
		LB_GoodCase=1
		echo "[ SNMP ]"
		echo "SNMP SERVICE NOT ACTIVATE"
		echo ""
	fi
	
	echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] SNMP V3 사용하고 있지 않음"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] Config 경로 확인"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 2 ]; then
			echo "[양호] SNMP V3 사용하고 있음"
			RESULT="GOOD"
		else
			echo "[양호] SNMP 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
	echo "-------------------------------------------------------------------"
		
} > $STATUS_FILE


:<<'END'
Unix_301(){ 
	{ 
		echo "양호 : 패스워드 최소길이가 8자리 이상, 영문, 숫자, 특수문자 최소 입력 기능이 설정된 경우" 
		echo "취약 : 패스워드 최소길이 8자리 미만, 영문, 숫자, 특수문자 최소 입력기능이 설정되어 있지 않은 경우" 
	}  > $STANDARD_FILE 2> /dev/null 
	 
	{ 
		LOGIN_LIMIT_OPTIONS="lcredit ucredit dcredit ocredit minlen"  
		  
		FCNT=0  
		OCNT=0  
		MCASE=0  
		OCASE=0  
		NOCASE=0  
		CASE=0  
		echo "-----------------------------------------------------------------"  
		echo "[ Password complexity (/etc/pam.d/system-auth) ]"  
		if [ -f /etc/pam.d/system-auth ]; then  
			FCNT=$(($FCNT+1))  
			for OPTION in ${LOGIN_LIMIT_OPTIONS}; do  
				if [ `cat /etc/pam.d/system-auth | grep -v '^#' | grep -i ${OPTION} | wc -l` -ge 1 ]; then				  
					OPTION_VALUE=`cat /etc/pam.d/system-auth | grep -v '^#' | grep -i ${OPTION} | awk -F"${OPTION}=" '{print $2}' | awk -F' ' '{print $1}'` 
					if [ `echo ${OPTION} | grep -w 'minlen' | wc -l` -ge 1 ]; then  
						if [ `echo ${OPTION_VALUE} | awk '$1<8' | wc -l` -ge 1 ]; then  
							MCASE=2  
						else  
							MCASE=1  
						fi  
					else  
						if [ `echo ${OPTION_VALUE} | grep '\-' | wc -l` -ge 1 ]; then 
							if [ `echo ${OPTION_VALUE} | sed 's/\-//g' | awk '$1>0' | wc -l` -ge 1 ]; then 
								OCNT=$(($OCNT+1))  
							fi 
						fi  
					fi  
					echo "${OPTION} : "`cat /etc/pam.d/system-auth | grep -v '^#' | grep -i ${OPTION}`
				else  
					echo "${OPTION} : /etc/pam.d/system-auth ${OPTION} OPTION NOT FOUND"  
				fi	  
			done  
			  
			if [ "${OCNT}" -ge 3 ]; then  
				OCASE=1  
			fi 
		else  
			NOCASE=1  
			echo "/etc/pam.d/system-auth FILE NOT FOUND"  
		fi  
		  
		if [ `echo ${MCASE} | grep '1' | wc -l` -ge 1 -a `echo ${OCASE} | grep '1' | wc -l` -ge 1 ]; then  
			CASE=1 #GOOD  
		else  
			CASE=2 #BAD  
		fi  
		  
		if [ "${NOCASE}" -eq 1 ]; then  
			CASE=3 #CHECK  
		fi  
		  
		echo "-----------------------------------------------------------------"  
		if [ "${CASE}" -eq 1 ]; then  
			echo "[양호] 패스워드 복잡도 설정이 올바름"  
			RESULT="GOOD"  
		elif [ "${CASE}" -eq 2 ]; then  
			#echo "[취약] 패스워드 복잡도 설정이 올바르지 않음"
			echo "[취약] "
			RESULT="BAD"  
		elif [ "${CASE}" -eq 3 ]; then  
			echo "[확인] /etc/pam.d/system-auth 파일 없음"  
			RESULT="CHECK"  
		fi  
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}
END

Unix_302(){
	{
		echo "양호 : 계정 잠금 임계값이 10회 이하의 값으로 설정되어 있는 경우"
		echo "취약 : 계정 잠금 임계값이 설정되어 있지 않거나, 10회 이하의 값으로 설정되지 않은 경우"
	} > $STANDARD_FILE
		
	{
		NoFile_chk=0
		Bad_chk=0
		Good_chk=0
		OS_Version=`uname -a | awk -F'.el' '{print $2}' | awk -F'.' '{print $1}'`

		echo "-------------------------------------------------------------------"
		for FILE in ${LOGIN_LIMIT_CONF}; do
			if [ -f ${FILE} ]; then
			echo "[ ${FILE} ]"
				NoConf_chk=0
				deny=0
				for MDL in ${LOGIN_LIMIT_MDL}; do
					if [ `cat ${FILE} | grep ${MDL} | grep -v "^#" | wc -l` -gt 0 ]; then
						deny=`cat ${FILE} | grep ${MDL} | grep -v "^#" | awk -F'deny=' '{print $2}' | awk '{print $1}'`
						cat ${FILE} | grep ${MDL} | grep -v "^#"

						if [  "${deny}" != "" ]; then
							echo ""
							echo "임계값 : ${deny}"
							if [ "${deny}" -le 10 ] && [ "${deny}" -ge 1 ]; then
								Good_chk=$((Good_chk+1))
							fi
						else
							NoConf_chk=$((NoConf_chk+1))
						fi
					else
						NoConf_chk=$((NoConf_chk+1))
					fi
				done
				
				if [ "${NoConf_chk}" -eq 3 ]; then
					echo "DENY NOT FOUND"
					echo ""
					Bad_chk=$((Bad_chk+1))
				fi	
			else
				if [ `echo ${FILE} | grep '/etc/pam.d/password-auth' | wc -l` -ge 1 ]; then
					if [ `echo ${OS_Version} | wc -l` -eq 0 ]; then
						echo "OS 버전을 알 수 없어 파일 사용여부 확인 필요"
						NoFile_chk=$((NoFile_chk+1))
					elif [ `echo ${OS_Version} | grep '5' | wc -l` -ge 1 -o `echo ${OS_Version} | grep '4' | wc -l` -ge 1 -o `echo ${OS_Version} | grep '3' | wc -l` -ge 1 -o `echo ${OS_Version} | grep '2' | wc -l` -ge 1 ]; then
						echo "RHEL 5 이하 버전은 사용하지 않음"
					fi
				else
					echo "FILE NOT FOUND"
					NoFile_chk=$((NoFile_chk+1))
				
				fi
			fi
		done

		echo "-------------------------------------------------------------------"
		if [ "${NoFile_chk}" -gt 0 ]; then
			echo "[확인] /etc/pam.d/password-auth 및 system-auth 파일이 존재하지 않음"
			Good_chk=0
			RESULT="CHECK"
		
		else
			if [ "${Bad_chk}" -gt 0 ]; then
				Good_chk=0
				echo "[취약] "
				RESULT="BAD"
			else
				echo "[양호] 패스워드 임계값 설정이 10이하로 설정되어 있음"
				RESULT="GOOD"
			fi
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

:<<'END'
Unix_303(){
	{
		echo "양호: shadow 패스워드를 사용하거나, 패스워드를 암호화하여 저장하는 경우" 
		echo "취약: shadow 패스워드를 사용하지 않고, 패스워드를 암호화하여 저장하지 않는 경우" 
	} > $STANDARD_FILE

	{
		CNT=0
		echo "-------------------------------------------------------------------"
		echo "[ /etc/shadow FILE CHECK ]"
			if [ -f /etc/shadow ]; then
				CNT=$(($CNT+1))				
				ls -alL /etc/shadow
			else
				echo "${GS_ShadowConf} FILE NOT FOUND"
			fi
			echo "-------------------------------------------------------------------"
			if [ "${CNT}" -gt 0 ]; then
				echo "[양호] ${GS_ShadowConf} 파일을 사용하여 패스워드를 암호화하여 저장함"
				RESULT="GOOD"
			else
				echo "[확인] shadow 패스워드 파일이 존재하지 않음. 타 파일에 암호화하여 저장하는지 확인"
				RESULT="CHECK"
			fi
			echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}
END

Unix_304(){
	{
		echo "양호 : /etc/shadow 파일의 소유자가 root이고, 권한이 400이하인 경우"
		echo "취약 : /etc/shadow 파일의 소유자가 root가 아니거나, 권한이 400이하가 아닌 경우"
	}  > $STANDARD_FILE

	{
		echo "-----------------------------------------------------------------"
		echo "[ /etc/shadow ]"
		if [ -f /etc/shadow ]; then
			ls -alL /etc/shadow
		else
			echo "/etc/shadow FILE NOT FOUND."
		fi
		echo "-----------------------------------------------------------------"
		if [ -f /etc/shadow ]; then
			if [ \( `ls -alL /etc/shadow | awk '{print $3}' | grep -i root | wc -l` -eq 1 \) -a \( `ls -alL /etc/shadow | grep '^-.--------' | wc -l` -eq 1 \) ]; then
				RESULT="GOOD"
				echo "[양호] /etc/shadow 소유자 및 권한 설정 양호"
			elif [ `ls -alL /etc/shadow | awk '{print $3}' | grep -i root | wc -l` -eq 1 ]; then 
				RESULT="BAD"
				#echo "[취약] /etc/shadow 권한 설정 미흡"
				echo "[취약] "
			elif [ `ls -alL /etc/shadow | grep '^-.--------' | wc -l` -eq 1 ]; then 
				RESULT="BAD"
				#echo "[취약] /etc/shadow 소유자 설정 미흡"
				echo "[취약] "
			else
				RESULT="BAD"
				#echo "[취약] /etc/shadow 소유자 및 권한 설정 미흡"
				echo "[취약] "
			fi
		else
			RESULT="CHECK"
			echo "[확인] /etc/shadow 파일이 존재하지 않음, 수동점검"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_305(){
	{
		echo "양호 : /etc/hosts 파일의 소유자가 root이고, 권한이 644 이하인 경우"
		echo "취약 : /etc/hosts 파일의 소유자가 root가 아니거나, 권한이 644 이하가 아닌 경우"
	}  > $STANDARD_FILE

	{
		echo "-----------------------------------------------------------------"
		echo "[ ${HOSTS_CONF} ]"
		if [ -f ${HOSTS_CONF} ]; then
			ls -alL ${HOSTS_CONF}
		fi
		echo "-----------------------------------------------------------------"
		if [ -f ${HOSTS_CONF} ]; then
			HOSTS_OWNER=$(ls -alL ${HOSTS_CONF} 2>/dev/null | awk '{print $3}')
			HOSTS_PERM=$(ls -alL ${HOSTS_CONF} 2>/dev/null | awk '{print $1}')
			LB_BadCase=0

			if [ "$HOSTS_OWNER" != "root" ]; then
				echo "[취약] 소유자가 root가 아님: $HOSTS_OWNER"
				LB_BadCase=1
			fi

			# 644 이하 확인: group write/execute 없고 other write/execute 없음
			if echo "$HOSTS_PERM" | grep -q '^-...[^-]..'; then
				# group에 w 또는 x 존재 여부 확인
				GRP_PERM=$(echo "$HOSTS_PERM" | cut -c5-7)
				OTH_PERM=$(echo "$HOSTS_PERM" | cut -c8-10)
				if echo "$GRP_PERM" | grep -q '[wx]'; then
					echo "[취약] 그룹에 쓰기/실행 권한 존재: $HOSTS_PERM"
					LB_BadCase=1
				fi
				if echo "$OTH_PERM" | grep -q '[wx]'; then
					echo "[취약] 기타 사용자에 쓰기/실행 권한 존재: $HOSTS_PERM"
					LB_BadCase=1
				fi
			fi

			if [ $LB_BadCase -eq 0 ]; then
				RESULT="GOOD"
				echo "[양호] ${HOSTS_CONF} 파일의 소유자 및 권한 설정 양호"
			else
				RESULT="BAD"
				echo "[취약] "
			fi
		else
			RESULT="CHECK"
			echo "[확인] ${HOSTS_CONF} 파일이 존재하지 않음, 수동점검"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_306(){ 
	{ 
		echo "양호 : /etc/services 파일의 소유자가 root(또는 bin, sys)이고, 권한이 644 이하인 경우" 
		echo "취약 : /etc/services 파일의 소유자가 root(또는 bin, sys)가 아니거나, 권한이 644 이하가 아닌 경우" 
	}  > $STANDARD_FILE 2> /dev/null 
	 
	{ 
 
		CNT=0 
		GOOD=0 
		echo "-------------------------------------------------------------------" 
		echo "[ ${SERVICES_CONF} permission ]"
		if [ -f ${SERVICES_CONF} ]; then 
			CNT=$(($CNT+1)) 
			ls -l ${SERVICES_CONF} 
			if [ `ls -l ${SERVICES_CONF} | awk '{print $3}' | egrep -i "root|bin|sys" | wc -l` -eq 1 -a `ls -l ${SERVICES_CONF} | grep '^-..-.--.--' | wc -l` -eq 1 ]; then 
				GOOD=1
			else
				BAD=1
			fi
		else
			echo "/etc/services NOT FOUND"
		fi 
		echo "-------------------------------------------------------------------" 
		if [ "${CNT}" -gt 0 ]; then 
			if [ "${BAD}" -gt 0 ]; then 
				echo "[취약]" 
				RESULT="BAD" 
			else
				echo "[양호] /etc/services 파일의 소유자와 권한 설정이 양호" 
				RESULT="GOOD"
			fi 
		else 
			echo "[확인] ${SERVICES_CONF}을 찾을 수 없음" 
			RESULT="CHECK" 
		fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 2> /dev/null 
}

Unix_307(){ 
	{ 
		echo "양호: 홈 디렉터리 환경변수 파일 소유자가 root 또는 해당 계정이고, root와 소유자만 쓰기 권한이 부여된 경우"
		echo "취약: 홈 디렉터리 환경변수 파일 소유자가 root 또는 해당 계정이 아니거나, 소유자 외에 쓰기 권한이 부여된 경우" 
	}  > $STANDARD_FILE 
 
	{ 
		USER_HOMEDIR=`cat /etc/passwd | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F":" '{print $1":"$6}' | sort | uniq` 
		 
		OCNT=0 
		WCNT=0 
		CASE=0 
		LI_FileExist=0
		echo "-----------------------------------------------------------------" 
		echo "[ HOME Directory ]"
		for USER_DIR in ${USER_HOMEDIR}; do 
			DIR=`echo ${USER_DIR} | awk -F':' '{print $2}'` 
			USER=`echo ${USER_DIR} | awk -F':' '{print $1}'` 
	 
			for ENV in ${GS_ENVFiles}; do 
				if [ -f ${DIR}/${ENV} ]; then 
					LI_FileExist=1
					if [ `ls -ald ${DIR}/${ENV} 2> /dev/null | awk '{print $3}' | grep -w 'root' | wc -l` -eq 0 -a `ls -ald ${DIR}/${ENV} 2> /dev/null | awk '{print $3}' | grep -w ${USER} | wc -l` -eq 0 ]; then 
						OCNT=$(($OCNT+1)) 
					fi 
					if [ `ls -ald ${DIR}/${ENV} | grep "^-....-..-." | wc -l` -eq 0 ]; then 
						WCNT=$(($WCNT+1)) 
					fi 
					echo "${USER} : "`ls -ald ${DIR}/${ENV}` 
				fi 
			done 
		done
		if [ ${LI_FileExist} -eq 0 ]; then
			echo "ENV_FILE NOT FOUND"
		fi
		 
		echo "-----------------------------------------------------------------" 
		if [ "${OCNT}" -ge 1 ]; then 
			#echo "[취약] 환경변수 파일의 소유자가 root가 아니거나 홈 디렉터리 소유자가 아님" 
			CASE=2 
		fi 
		if [ "${WCNT}" -ge 1 ]; then 
			#echo "[취약] 환경변수 파일의 권한이 올바르지 않음" 
			CASE=2 
		fi 
		if [ "${CASE}" -eq 0 ]; then 
			echo "[양호] 환경변수 파일의 권한이 올바르게 되어 있음"
			RESULT="GOOD" 
		else 
			echo "[취약] "
			RESULT="BAD" 
		fi 
		echo "-----------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

# Unix_308(){
	# {
		# echo "양호: dev에 대한 파일 점검 후 존재하지 않는 device 파일을 제거한 경우"
		# echo "취약: dev에 대한 파일 미점검 또는 존재하지 않는 device 파일을 방치한 경우" 
	# } > $STANDARD_FILE
	
	# {
		# CNT=0
		# CCNT=0
		# BADCASE=0
		# echo "-------------------------------------------------------------------"
		# DEVFILENAME=`find /dev -type f -exec ls -l {} \; | grep -v '/dev/nul' | grep -v '/dev/rmt0' | awk -F" " '{print $9}'`
		# # DEVFILENAME로 변수로 if 타게 되면 아무것도 출력되지 않을때 빈값이 들어가 취약으로 나오게됨
		# if [ `find /dev -type f -exec ls -l {} \; | grep -v '/dev/nul' | grep -v '/dev/rmt0' | wc -l` -gt 0 ]; then
			# CNT=$(($CNT+1))
			# for FILE in ${DEVFILENAME}; do
				# echo "[ ${FILE} ]"
				# ls -al ${FILE}
				# if [ `ls -al ${FILE} | grep ',' | wc -l` -gt 0 ]; then
					# CCNT=$(($CCNT+1))
					# MAJOR=`ls -al ${FILE} | awk -F" " '{print $5 $6}' | awk -F"," '{print "major :" $1}'`
					# MINOR=`ls -al ${FILE} | awk -F" " '{print $5 $6}' | awk -F"," '{print "minor :" $2}'`
					# MAJORV=`ls -al ${FILE} | awk -F" " '{print $5 $6}' | awk -F"," '{print "major :" $1}' | awk -F ":" '{print $2}'`
					# MINORV=`ls -al ${FILE} | awk -F" " '{print $5 $6}' | awk -F"," '{print "minor :" $2}' | awk -F ":" '{print $2}'`
					# if [ "${MAJORV}" -ge 0 -o "${MAJORV}" -ge 0 ]; then
						# true
					# else
						# BADCASE=$(($BADCASE+1))
						# #major나 minor 값이 없는 경우 취약.
					# fi
				# fi
			# done
		# else
			# echo "FILE NOT FOUND"
		# fi
		# echo "-------------------------------------------------------------------"
			# if [ "${CNT}" -gt 0 ]; then
				# if [ "${CCNT}" -gt 0 ]; then
					# if [ "${BADCASE}" -gt 0 ]; then
						# echo "[취약]"
						# RESULT="BAD"
					# else
						# echo "[양호] dev 관련 파일이 존재하지만, MAJOR, MINOR 값을 모두 보유"
						# RESULT="GOOD"
					# fi
				# else
					# echo "[취약]"
					# RESULT="BAD"
					# #파일이 장비와 관련되지 않은 파일이 존재
				# fi
			# else
				# echo "[양호] dev에 대한 파일 점검 후 존재하지 않는 device 파일을 제거한 경우"
				# RESULT="GOOD"
			# fi
		# echo "-------------------------------------------------------------------"
	# } > $STATUS_FILE 2> /dev/null 
# }

Unix_309(){
	{
		echo "양호: login, shell, exec 서비스를 사용하지 않거나, 사용 시 아래와 같은 설정이 적용된 경우" 
		echo "1. /etc/hosts.equiv 및 \$HOME/.rhosts 파일 소유자가 root 또는, 해당 계정인 경우" 
		echo "2. /etc/hosts.equiv 및 \$HOME/.rhosts 파일 권한이 600 이하인 경우" 
		echo "3. /etc/hosts.equiv 및 \$HOME/.rhosts 파일 설정에 '+' 설정이 없는 경우" 
		echo "취약: login, shell, exec 서비스를 사용하고, 위와 같은 설정이 적용되지 않은 경우" 
	}  > $STANDARD_FILE

	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LI_ServiceExist=0
		# LS_LSEServices="rlogin.socket rsh.socket rsh rexec"
		
		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER "rlogin" "rlogin.socket"
		
		if [ ${PCK} -eq 1 ]; then
			LI_ServiceExist=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ rlogin ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ rlogin ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		fi
		
		PROCESS_CHECKER "rsh" "rsh.socket"
		
		if [ ${PCK} -eq 1 ]; then
			LI_ServiceExist=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ rlogin ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ rlogin ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		fi		
		
		PROCESS_CHECKER "rexec" "rexec.socket"
		
		if [ ${PCK} -eq 1 ]; then
			LI_ServiceExist=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ rlogin ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ rlogin ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		fi	
		
		if [ ${LI_ServiceExist} -gt 0 ]; then
			if [ -f ${GS_PasswdConf} ]; then
				USER_HOMEDIR=`cat ${GS_PasswdConf} | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F":" '{print $1":"$6}'`
			else
				echo "${GS_PasswdConf} FILE NOT FOUND"
				LB_CheckCase1=1
			fi
			
			for USER_DIR in ${USER_HOMEDIR}; do 
				DIR=`echo ${USER_DIR} | awk -F':' '{print $2}'` 
				USER=`echo ${USER_DIR} | awk -F':' '{print $1}'`
				DIRNUM=$(($DIRNUM+1))
				if [ -f ${DIR}/.rhosts ]; then
					echo "[ /.rhosts Permission ]"
					ls -alLd ${DIR}/.rhosts
					echo ""
					
					if [ `ls -alLd ${DIR}/.rhosts 2> /dev/null | awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
						if [ `ls -alLd ${DIR}/.rhosts | grep '^-..-------' | wc -l` -eq 0 ]; then
							LB_BadCase=1
						fi
					elif [ `ls -alLd ${DIR}/.rhosts 2> /dev/null | awk '{print $3}' | grep -i ${USER} | wc -l` -gt 0 ]; then
						if [ `ls -alLd ${DIR}/.rhosts | grep '^-..-------' | wc -l` -eq 0 ]; then
							LB_BadCase=1
						fi
					else
						LB_BadCase=1
					fi
					
					echo "[ /.rhosts Content ]"
					if [ `cat ${DIR}/.rhosts | awk -F"#" '{print $1}' | sed '/^$/d' | grep '^+' | wc -l` -gt 0 ]; then
						LB_BadCase=1
						cat ${DIR}/.rhosts | awk -F"#" '{print $1}' | sed '/^$/d' | grep '^+'
					else
						echo "\"+\" NOT FOUND"
					fi
					echo ""
				else 
					FILEEXIST=$(($FILEEXIST+1))
				fi
			done
			
			if [ $FILEEXIST -eq $DIRNUM ]; then
				echo ".rhosts NOT FOUND"
				echo ""
			fi
			
			if [ -f /etc/hosts.equiv ]; then
				echo "[ /etc/hosts.equiv Permission ]"
				ls -ald /etc/hosts.equiv
				echo ""
				
				if [ `ls -aldL ${DIR}/.rhosts 2> /dev/null | awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
					if [ `ls -aldL ${DIR}/.rhosts | grep '^-..-------' | wc -l` -eq 0 ]; then
						LB_BadCase=1
					fi
				elif [ `ls -aldL ${DIR}/.rhosts 2> /dev/null | awk '{print $3}' | grep -i ${USER} | wc -l` -gt 0 ]; then
					if [ `ls -aldL ${DIR}/.rhosts | grep '^-..-------' | wc -l` -eq 0 ]; then
						LB_BadCase=1
					fi
				else
					LB_BadCase=1
				fi
				
				echo "[ cat /etc/hosts.equiv Content ]"
				if [ `cat /etc/hosts.equiv | awk -F"#" '{print $1}' | sed '/^$/d' | grep '^+' | wc -l` -gt 0 ]; then
					cat /etc/hosts.equiv | awk -F"#" '{print $1}' | sed '/^$/d' | grep '^+'
					LB_BadCase=1
				else
					echo "\"+\" NOT FOUND"
				fi
			else
				echo "/etc/hosts.equiv NOT FOUND"
			fi
		else
			echo "[ SERVICE CHECK ]"
			echo "login, shell, exec SERVICE NOT ACTIVATE"
			LB_GoodCase=1
		fi
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] "
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 1 ]; then
			echo "[양호] login, shell, exec 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] login, shell, exec 서비스가 구동 중이지만 설정이 양호함"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

Unix_310(){
	{
		echo "양호: 불필요한 r 계열 서비스가 비활성화 되어 있는 경우" 
		echo "취약: 불필요한 r 계열 서비스가 활성화 되어 있는 경우" 
	} > $STANDARD_FILE
		
	{
		LS_RServices="rlogin rsh rexec"
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		
		for LS_Service in ${LS_RServices}; do
		
			PROCESS_CHECKER ${LS_Service}
			
			INETDON=0
			
			if [ ${PCK} -eq 1 ]; then
				LB_CheckCase1=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} 서비스가 구동중이지 않음"
				echo ""
			fi
		done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] r계열 서비스가 활성화되어 있어 업무상에 필요한 서비스 인지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] r계열 서비스가 구동중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}

Unix_312(){
	{
		echo "양호: NIS 서비스가 비활성화 되어 있거나, 필요 시 NIS+를 사용하는 경우" 
		echo "취약: NIS 서비스가 활성화 되어 있는 경우" 
	} > $STANDARD_FILE

	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		
		for LS_Service in ${GS_NISServices}; do
			
			PROCESS_CHECKER ${LS_Service}
			
			INETDON=0
			
			if [ ${PCK} -eq 1 ]; then
				LB_CheckCase1=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} 서비스가 구동중이지 않음"
				echo ""
			fi
		done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] NIS 서비스 활성화. NIS+ 서비스 인지 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] NIS 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}

Unix_313(){
	{
		echo "양호 : 패스워드 최소 길이가 8자 이상으로 설정되어 있는 경우"
		echo "취약 : 패스워드 최소 길이가 8자 미만으로 설정되어 있는 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "[ /etc/pam.d/system-auth (Priority UP) ]"
		if [ -f /etc/pam.d/system-auth ]; then
			if [ `cat /etc/pam.d/system-auth | awk -F"#" '{print $1}' | grep -i -E 'cracklib.so|pwquality.so' | grep -i 'minlen' | wc -l` -ge 1 ]; then
				cat /etc/pam.d/system-auth | awk -F"#" '{print $1}' | grep -i -E 'cracklib.so|pwquality.so' | grep -i 'minlen'
			else
				echo "minlen OPTION NOT FOUND"
			fi
		else
			echo "system-auth FILE NOT FOUND"
			echo ""
			echo "[ /etc/login.defs ]"
			if [ -f /etc/login.defs ]; then
				if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_LEN" | wc -l` -ge 1 ]; then
					cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_LEN"
				else
					echo "PASS_MIN_LEN OPTION NOT FOUND"
				fi
			else
				echo "login.defs FILE NOT FOUND"
			fi
		fi
		echo "-------------------------------------------------------------------"
		
		if [ -f /etc/pam.d/system-auth ]; then
			if [ `cat /etc/pam.d/system-auth 2> /dev/null | grep -v "#" | grep -i -E 'cracklib.so|pwquality.so' | awk -F'minlen=' '{print $2}' | awk -F' ' '$1>=8' | wc -l` -gt 0 ] || [ `cat /etc/pam.d/system-auth 2> /dev/null | grep -v "#" | grep -i 'pwq.so' | awk -F'minlen=' '{print $2}' | awk -F' ' '$1>=8' | wc -l` -gt 0 ]; then
				echo "[양호] system-auth 파일의 패스워드 최소 길이 설정이 8자리 이상으로 설정되어 있음"
				RESULT="GOOD"
			else
				echo "[취약] "
				RESULT="BAD"
			fi
			
		elif [ -f /etc/login.defs ]; then
			if [ `cat /etc/login.defs 2> /dev/null | grep -v "#" | grep -i 'PASS_MIN_LEN' | awk '$2>=8'| wc -l` -gt 0 ]; then
				echo "[양호] login.defs 파일의 패스워드 최소 길이 설정이 8자리 이상으로 설정되어 있음"
				RESULT="GOOD"
			else
				echo "[취약] "
				RESULT="BAD"
			fi
			
		else
			echo "[확인] system-auth, login.defs 찾을 수 없어 수동 점검 진행"
			RESULT="CHECK"
		fi
		
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}

Unix_314(){
	{
		echo "양호: 패스워드 최대 사용기간이 90일(12주) 이하로 설정되어 있는 경우"
		echo "취약: 패스워드 최대 사용기간이 90일(12주) 이하로 설정되어 있지 않는 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "[ /etc/login.defs (PASS_MAX_DAYS) ]"
		if [ -f /etc/login.defs ]; then
			if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MAX_DAYS" | wc -l` -ge 1 ]; then
				cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MAX_DAYS"
			else
				echo "Option NOT FOUND"
			fi
		else
			echo "/etc/login.defs FILE NOT FOUND"
		fi
		
		echo ""
		echo "[ /etc/shadow (PASS_MAX_DAYS) ]"
		if [ -f /etc/shadow ]; then
			cat /etc/shadow | awk -F: '{print $1":"$2":"$5}' | awk -F: '$2!="*"' | awk -F: '$2!="!!"'
		else
			echo "/etc/shadow FILE NOT FOUND"
		fi
		echo "-------------------------------------------------------------------"
		USER_LIST=`cat /etc/passwd | egrep -v '/bin/false'| awk -F: '{print $1}'`
		CNT=0
		CASE=0
		if [ -f /etc/login.defs ]; then
			if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MAX_DAYS" | awk '$2<=90' | awk '$2>0' | wc -l` -ge 1 ]; then
				if [ -f /etc/shadow ]; then
					for i in $USER_LIST; do
						if [ `cat /etc/shadow | grep -i "$i" | awk -F: '$2!="*"' | awk -F: '$2!="!!"' | awk -F: '$5>90' | wc -l` -eq 0 ]; then
							CNT=$(($CNT))
						else
							# 계정별 패스워드 최대사용 기간 설정이 올바르게 설정되어 있지 않음
							CNT=$(($CNT+1))
						fi
					done
				else
					CASE=1
				fi
			else
				# 패스워드 최대 사용 기간설정이 올바르게 설정되어 있지 않음
				CNT=$(($CNT+1))
			fi
		else
			CASE=2
		fi
		
		if [ "${CASE}" -eq 1 ]; then
			echo "[확인] /etc/shadow 파일을 찾을 수 없으므로 수동 체크"
			RESULT="CHECK"
		elif [ "${CASE}" -eq 2 ]; then
			echo "[확인] /etc/login.defs 파일을 찾을 수 없으므로 수동 체크"
			RESULT="CHECK"
		elif [ "${CNT}" -eq 0 ]; then
			echo "[양호] 계정별 비밀번호 최대 사용 기간 설정이 적용되어 있음"
			RESULT="GOOD"
		else
			echo "[취약] "
			RESULT="BAD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}

Unix_315(){
	{
		echo "양호: 패스워드 최소 사용기간이 1일 이상 설정되어 있는 경우"
		echo "취약: 패스워드 최소 사용기간이 설정되어 있지 않는 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "[ /etc/login.defs (PASS_MIN_DAYS) ]"
		if [ -f /etc/login.defs ]; then
			if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_DAYS" | wc -l` -ge 1 ]; then
				cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_DAYS"
			else
				echo "패스워드 최소 사용기간 설정이 존재하지 않음"
			fi
		else
			echo "/etc/login.defs 파일을 찾을 수 없음"
		fi
		
		echo ""
		if [ -f /etc/shadow ]; then
			echo "[ /etc/shadow (MIN_DAYS) ]"
			cat /etc/shadow | grep -v "^#" | awk -F: '{print $1":"$2":"$4}' | awk -F: '$2!="*"' | awk -F: '$2!="!!"'
		fi
		echo "-------------------------------------------------------------------"
		if [ -f /etc/login.defs ]; then
			if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_DAYS" | wc -l` -ge 1 ]; then
				if [ `cat /etc/login.defs | awk -F"#" '{print $1}' | grep -i "PASS_MIN_DAYS" | awk '{print $2}'` -eq 0 ]; then
					#echo "[취약] 패스워드 최소 사용기간 설정값이 0으로 취약"
					echo "[취약]"
					RESULT="BAD"
				else
					#if [ `cat /etc/login.defs | grep -v "^#" | grep -i "PASS_MIN_DAYS" | awk '{print $2}'` -ge 9999 ]; then
					#	#echo "[취약] 패스워드 최소 사용기간 설정값 Default(9999)"
					#	echo "[취약] "
					#	RESULT="BAD"
					#else
						echo "[양호] 패스워드 최소 사용기간이 1일 이상으로 설정되어 있음"
						RESULT="GOOD"
					#fi
				fi
			else
				#echo "[취약] PASS_MIN_DAYS 설정값 존재하지 않음"
				echo "[취약] "
				RESULT="BAD"
			fi
		else
			echo "[확인] /etc/login.defs 파일을 찾을 수 없으므로 수동 체크"
			RESULT="CHECK"
		fi
		
		while read MINDAY; do
			if [ `echo $MINDAY | awk -F":" '{if ($2!="!!" && $2!="*") print $4}'` -eq 0 ]; then
				badUser=`echo $MINDAY | awk -F":" '{ print $1 }'`
				echo "[취약] ${badUser}"
				RESULT="BAD"
			fi
			
		done < /etc/shadow
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_316(){
	{
		echo "양호: 불필요한 계정이 존재하지 않는 경우" 
		echo "취약: 불필요한 계정이 존재할 경우" 
	} > $STANDARD_FILE

	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		echo "-----------------------------------------------------------------"
		echo "[ Account List (${GS_PasswdConf}) ]"
		if [ -f ${GS_PasswdConf} ]; then
			cat ${GS_PasswdConf} | awk -F"#" '{print $1}' | sed '/^$/d' | awk -F":" '{print $1}'
			LB_CheckCase1=1
		else
			echo "FILE NOT FOUND"
			LB_CheckCase2=1
		fi
		
		echo "-----------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] [현황]의 계정들 중 로그인이 불필요한 계정이 존재하는지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] ${GS_PasswdConf} 파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}

Unix_317(){
	{
		echo "양호: hosts.lpd 파일이 삭제되어 있거나 불가피하게 hosts.lpd 파일을 사용할 시 파일의 소유자가 root이고 권한이 600인 경우"
		echo "취약: hosts.lpd 파일이 삭제되어 있지 않거나 파일의 소유자가 root가 아니고 권한이 600이 아닌 경우"
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------" 
		CNT=0 
		GOOD=0
		BAD=0
		echo "[ ${HOSTS_LPD} ]"
		if [ -f ${HOSTS_LPD} ]; then 
			CNT=$(($CNT+1))
			ls -alL ${HOSTS_LPD} 2> /dev/null 
			if [ \( `ls -alL ${HOSTS_LPD} 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 \) -a \( `ls -alL ${HOSTS_LPD} | grep '^-..-.-----' | wc -l` -eq 1 \) ]; then 
				GOOD=1
			else
				BAD=1
			fi
		else
			echo "hosts.lpd NOT FOUND"
		fi  
		echo "-------------------------------------------------------------------" 
			if [ "${CNT}" -gt 0 ]; then 
				if [ "${BAD}" -gt 0 ]; then 
					echo "[취약]" 
					RESULT="BAD" 
				else 
					echo "[양호] ${HOSTS_LPD} 파일의 소유자 및 권한 설정 양호" 
					RESULT="GOOD" 
				fi 
			else 
				echo "[양호] ${HOSTS_LPD} 파일을 확인할 수 없음" 
				RESULT="GOOD" 
			fi 
		echo "-------------------------------------------------------------------"	
	} > $STATUS_FILE 2> /dev/null 
}

Unix_318(){
	{
		echo "양호: 홈 디렉터리가 존재하지 않는 계정이 발견되지 않는 경우"
		echo "취약: 홈 디렉터리가 존재하지 않는 계정이 발견된 경우" 
	} > $STANDARD_FILE
	
	{
		CASE=1
		BADCASE=0
		echo "-------------------------------------------------------------------"
		HOMEDIR=`cat /etc/passwd | egrep -v '^#|bin/false|sbin/nologin' | awk -F ":" '{print $1":"$3":"$6}'`
		echo "[ User Home Directory ]"
		for HOMEDIR in ${HOMEDIR}; do
			USR=`echo ${HOMEDIR} | awk -F ":" '{print $1}'`
			USRID=`echo ${HOMEDIR} | awk -F ":" '{print $2}'`
			HOME=`echo ${HOMEDIR} | awk -F ":" '{print $3}'`
			
			if [ -d ${HOME} ]; then
				CNT=1
				if [ ${USRID} -ge 500 ]; then
					#homedir이 '/'일 경우
					if [ `echo ${HOME} | grep -w "/" | wc -l` -gt 0 ]; then
						echo "USER : ${USR}, HOME : ${HOME}"
						BADCASE=1
						echo ""
					#homedir이 공백일 경우
					elif [ `echo ${HOME} | grep -w "$" | wc -l` -gt 0 ]; then
						echo "USER : ${USR}, HOME : ${HOME}"
						BADCASE=1
					fi
				fi
			else
				BADCASE=1
				echo "USER : ${USR} / HOME : ${HOME}"
				echo "HOME DIR NOT FOUND"
				echo ""
			fi
		done
			
		if [ "${BADCASE}" -eq 0 ]; then
			echo "모든 사용자 계정 홈 디렉터리 존재"
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${BADCASE}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		else
			echo "[양호] 모든 사용자 계정의 홈 디렉터리가 존재함"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_319(){
	{
		echo "양호 : 홈 디렉터리 소유자가 해당 계정이고, 타 사용자 쓰기 권한이 제거된 경우"
		echo "취약 : 홈 디렉터리 소유자가 해당 계정이 아니거나, 타 사용자 쓰기 권한이 부여되어 있음"
	}  > $STANDARD_FILE

	{
		CNT=0
		GOODCASE=0
		BADCASE=0
		echo "-------------------------------------------------------------------"
		USER_HOMEDIR=`cat /etc/passwd | grep -v '/sbin/nologin' | grep -v '/bin/false' | awk -F":" '{print $1":"$3":"$6}'`
		echo "[ User Home Directory ]"
		for HOMEDIR in ${USER_HOMEDIR}; do
			USR=`echo ${HOMEDIR} | awk -F":" '{print $1}'`
			USRID=`echo ${HOMEDIR} | awk -F":" '{print $2}'`
			HOME=`echo ${HOMEDIR} | awk -F":" '{print $3}'`
			
			if [ -d ${HOME} ]; then
				CNT=1
				if [ ${USRID} -ge 500 -a ${USRID} -le 65534 ]; then
					HOMEID=`ls -ndL ${HOME} | awk '{print $3}'`
					# 홈디렉터리 소유자의 uid
					
					#양/취 상관없이 홈디렉터리 권한에 대한 현황은 출력
					echo "* USER : ${USR}, HOME : ${HOME}"
					echo `ls -adl ${HOME}`	
					echo ""	
					
					# 홈디렉터리 소유자가 root이거나 해당 계정이고, 타 사용자의 쓰기 권한이 제거된 경우
					if [ "${HOMEID}" -eq 0 -o "${USRID}" -eq "${HOMEID}" -a `ls -ald ${HOME} | grep '^d.......-.' | wc -l` -gt 0 ]; then
						GOODCASE=1 # 양호
					else
						# 그 외 경우가 하나라도 존재 시 취약
						BADCASE=1
					fi
				fi
			fi
		done
		
		if [ "${CNT}" -eq 0 ]; then
			echo "homedir NOT FOUND (all account)"
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${CNT}" -gt 0 ]; then
			if [ "${BADCASE}" -gt 0 ]; then
				echo "[취약]"
				RESULT="BAD"
			else
				echo "[양호] 홈 디렉터리 소유자가 root 또는 해당 계정이고, 타 사용자 쓰기 권한이 제거되어 있음"
				RESULT="GOOD"
			fi
		else
			echo "[확인] 모든 계정의 홈 디렉터리를 찾을 수 없음"
			RESULT="CHECK"
		fi
		echo "-------------------------------------------------------------------"
	
	} > $STATUS_FILE 2> /dev/null 
}

Unix_320(){
	{
		echo "양호 : 원격 접속 시 SSH 프로토콜을 사용하는 경우 "
		echo "※ ssh, telnet이 동시에 설치되어 있는 경우 취약한 것으로 평가됨"
		echo "취약 : 원격 접속 시 Telnet, FTP 등 안전하지 않은 프로토콜을 사용하는 경우"
	} > $STANDARD_FILE
	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LB_BadCase1=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER "sshd"
		if [ ${PCK} -eq 1 ]; then
			#LB_CheckCase1=1
			LB_CheckCase4=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ SSH ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ SSH ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ SSH ]"
			echo "SSH SERVICE NOT ACTIVATE"
		fi
		
		PROCESS_CHECKER "ftp"
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ FTP ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ FTP ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ FTP ]"
			echo "FTP SERVICE NOT ACTIVATE"
		fi
		
		PROCESS_CHECKER "telnet" "telnet.socket"
		if [ ${PCK} -eq 1 ]; then
			LB_CheckCase1=1
			if [ ${LB_CheckCase4} -eq 1 ]; then
				LB_BadCase1=1
				echo ""
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ Telnet ]"
			echo "inetd SERVICE ACTIVE, inetd.conf 	FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ Telnet ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ Telnet ]"
			echo "Telnet SERVICE NOT ACTIVATE"
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ ${LB_BadCase1} -eq 1 ]; then
			echo "[취약]"
			RESULT="BAD"		
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
        	echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
         	RESULT="CHECK"
		else
			echo "[양호] 안전하지 않은 프로토콜을 사용하고 있지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_321(){
	{
		echo "양호: 서버 및 주요 서비스에 로그인 시 경고 메시지가 설정된 경우"
		echo "취약: 서버 및 주요 서비스에 로그인 시 경고 메시지가 설정되어 있지 않은 경우"
	} > $STANDARD_FILE
	{

		echo "-------------------------------------------------------------------"
		echo "[ Server Login Message (/etc/motd) ]"
		if [ -f /etc/motd ]; then
			if [ `cat /etc/motd | wc -l` -gt 0 ]; then
				cat /etc/motd 
			else 
				echo "FILE NOT FOUND"
			fi
		else
			echo "/etc/motd FILE NOT FOUND"
		fi
		echo ""
		
		echo "[ Server Login Message (/etc/issue) ]"
		if [ -f /etc/issue ]; then
			if [ `cat /etc/issue | wc -l` -gt 0 ]; then		
				cat /etc/issue 	
			else 
				echo "FILE NOT FOUND"
			fi				
		else
			echo "/etc/issue FILE NOT FOUND"
		fi		
		echo ""
		
		
		PROCESS_CHECKER "telnet" "telnet.socket"
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ Telnet Login Message (/etc/issue.net) ]" 
			if [ -f /etc/issue.net ]; then 
				echo "/etc/issue.net : " 
				cat etc/issue.net 
			else
				echo "FILE NOT FOUND"
			fi 
			echo ""
			
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ Telnet ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ Telnet ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ Telnet ]"
			echo " Telnet SERVICE NOT ACTIVATE"
			echo ""
		fi

		PROCESS_CHECKER ftp
		LS_Result=`PROCESS_CHECKER ftp` 
		if [ ${PCK} -eq 1 ]; then
			if [ `echo ${LS_Result} | grep -i vsftp | wc -l` -gt 0 ]; then
				for LS_File1 in ${GS_VsFTPConf}; do
					echo "[ vsFTP Login Message ]" 
					if [ -f ${LS_File1} ];then 
						LI_FileExist1=1
						if [ `cat ${LS_File1} | grep -i 'ftpd_banner' | grep -v '^#' | wc -l` -gt 0 ]; then 
							echo "${LS_File1} : " 
							cat ${LS_File1} | grep -i 'ftpd_banner' 
							echo "" 
						else
							echo "${LS_File1} : ftpd_banner OPTIONS NOT FOUND"
						fi 
						
					else
						echo "${LS_File1} NOT FOUND"
					fi 
				done 

				if [ ${LI_FileExist1} -eq 0 ]; then
					echo "vsFTP FILE NOT FOUND"
					echo ""
				fi

			elif [ `echo ${LS_Result} | grep -i proftp | wc -l` -gt 0 ]; then 
				for LS_File2 in ${GS_ProFTPConf}; do
					echo "[ proFTP Login Message ]" 
					if [ -f ${LS_File2} ];then 
						LI_FileExist2=1					
						if [ `cat ${LS_File2} | grep -i 'ServerIdent' | grep -v '^#' | grep -i 'on' | wc -l` -gt 0 ]; then 
							echo "${LS_File2} : " 
							cat ${LS_File2} | grep -i 'ServerIdent' 
							echo "" 
						else
							echo "${LS_File2} : ServerIdent OPTIONS NOT FOUND"
						fi 
					fi 
				done 
				if [ ${LI_FileExist2} -eq 0 ]; then
					echo "proFTP FILE NOT FOUND"
					echo ""
				fi

			else 
				echo "[ /etc/ftpaccess Login Message ]" 
				if [ -f /etc/ftpaccess ]; then 
					if [ `cat /etc/ftpaccess | grep -i "greeting" | grep -i "full" | grep -v '^#' | wc -l` -gt 0 ]; then 
						echo "/etc/ftpaccess : " 
						cat /etc/ftpaccess | grep -i 'greeting' 
						echo "" 
					else 
						echo " greeting NOT FOUND"
					fi 
				else 
					echo "/etc/ftpaccess FILE NOT FOUND" 
				fi 
			fi

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ ftp ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ ftp ]"
			echo "ftp service not found"
			echo ""
		fi

		PROCESS_CHECKER sendmail		
		echo ""
		if [ ${PCK} -eq 1 ]; then
			echo "[ SMTP Sendmail Login Message ]" 
			if [ -f /etc/mail/sendmail.cf ]; then 
				if [ `cat /etc/mail/sendmail.cf | grep -i "SMTPGreetingMessage" | grep -v '^#' | wc -l` -gt 0 ]; then 
					cat /etc/mail/sendmail.cf | grep -i "SMTPGreetingMessage" 
				else
					echo "SMTPGreetingMessage NOT FOUND"
				fi 
			else 
				echo "/etc/mail/sendmail.cf FILE NOT FOUND" 
			fi 
		
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT FOUND"
			echo ""
		fi
		echo ""

		PROCESS_CHECKER postfix
		echo ""
		if [ ${PCK} -eq 1 ]; then	
			echo "[ SMTP Postfix Login Message ]"
			if [ -f /etc/postfix/main.cf ]; then
				if [ `cat /etc/postfix/main.cf | grep -v '^#' | grep -i "smtpd_banner" | wc -l` -gt 0 ]; then 
					cat /etc/postfix/main.cf| grep -i "smtpd_banner"
				else
					echo "smtpd_banner NOT FOUND"
					echo ""
				fi
			else 
				echo "/etc/postfix/main.cf FILE NOT FOUND" 
				echo ""
			fi

		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ postfix ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ postfix ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ postfix ]"
			echo "postfix SERVICE NOT ACTIVATE"
			echo ""
		fi

		PROCESS_CHECKER named
		echo ""
		if [ ${PCK} -eq 1 ]; then
			echo "[ DNS named Login Message ]"
			for LS_File in ${GS_DNSConf}; do
				if [ -f ${LS_File} ]; then
					echo "${LS_File} : "
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'version' | wc -l` -gt 0 ]; then #버전이 존재함
						cat ${LS_File} | awk -F"#" '{print $1}' | awk -F"//" '{print $1}' | awk '{if (match($0, /\/\*/) > 0){begin=1; print substr($0,0,match($0, /\/\*/)-1)} if (begin == 0){print $0} if (match($0, /\*\//) > 0) {begin=0; print substr($0,match($0, /\*\//)+2, length($0))}}' | grep -i 'version'
		            else
		                echo "version OPTION NOT FOUND"
		            fi
				fi
			done
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo " named SERVICE NOT ACTIVATE"
			echo ""
		fi

		if [ ${LI_FileExist} -eq 0 ]; then
			echo "named config FILE NOT FOUND" 
		fi

		
		echo "-------------------------------------------------------------------"
			echo "[확인] 설정 파일 확인 후 수동 점검" 
			echo "proftp 구동 중일 경우 버전 정보 확인 필요 ( 버전 확인 옵션 : [proftpd 실행 파일 경로] -v ) "
				RESULT="CHECK" 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE
}




Unix_322(){
	{
		echo "양호: NFS 접근제어 설정파일의 소유자가 root 이고, 권한이 644 이하인 경우"
		echo "취약: NFS 접근제어 설정파일의 소유자가 root가 아니거나, 권한이 644이하가 아닌 경우"
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER nfsd
		
		if [ ${PCK} -eq 1 ]; then
			echo ""
			echo "[ NFS file permission ]"
			if [ -f /etc/exports ]; then
				ls -alL /etc/exports
				if [ `ls -alL /etc/exports 2> /dev/null | awk '{print $3}' | grep -i 'root' | wc -l` -gt 0 ]; then
					if [ `ls -alL /etc/exports | grep '^-..-.--.--' | wc -l` -eq 0 ]; then #권한이 644가 아님
						LB_BadCase=1
					fi
				else
					LB_BadCase=1
				fi
			else
				echo "/etc/exports FILE NOT FOUND"
				LB_CheckCase1=1
			fi
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ nfsd ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ nfsd ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ nfsd ]"
			echo "NFS SERVICE NOT ACTIVATE"
			echo ""
			LB_GoodCase=1
		fi
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] /etc/exports 파일이 존재하지 않음 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 1 ]; then
			echo "[양호] NFS 서비스 비활성화"
			RESULT="GOOD"
		else
			echo "[양호] NFS 접근제어 설정파일 소유자 및 권한 설정 양호"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_323(){
	{
		echo "양호 : /etc/inetd.conf 파일의 소유자가 root이고, 권한이 600인 경우"
		echo "취약 : /etc/inetd.conf 파일의 소유자가 root가 아니거나, 권한이 600이 아닌 경우"
	}  > $STANDARD_FILE

	{
		echo "-----------------------------------------------------------------" 		 
		if [ -f ${XINETD_CONF} ]; then 
			echo "[${XINETD_CONF}]"	
			ls -alL ${XINETD_CONF} 2> /dev/null
			echo "-----------------------------------------------------------------" 
			if [ \( `ls -alL ${XINETD_CONF} 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 \) -a \( `ls -alL ${XINETD_CONF} | grep '^-..-------' | wc -l` -eq 1 \) ]; then 
				RESULT="GOOD" 
				echo "[양호] ${XINETD_CONF}의 소유자 및 권한 설정 양호" 
			elif [ `ls -alL ${XINETD_CONF} 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 ]; then 
				RESULT="BAD" 
				#echo "[취약] ${XINETD_CONF}의 권한 설정 미흡" 
				echo "[취약] "
			elif [ `ls -alL ${XINETD_CONF} 2> /dev/null | grep '^-..-------' | wc -l` -eq 1 ]; then 
				RESULT="BAD" 
				#echo "[취약] ${XINETD_CONF}의 소유자 설정 미흡" 
				echo "[취약] "
			else 
				RESULT="BAD"
				#echo "[취약] ${XINETD_CONF}의 소유자 및 권한 설정 미흡" 
				echo "[취약] "
			fi 
			echo "-----------------------------------------------------------------" 
		elif [ -f ${INETD_CONF} ]; then 
			echo "[ ${INETD_CONF} ]"
			echo "-----------------------------------------------------------------" 	
			ls -alL ${INETD_CONF} 2> /dev/null
			echo "-----------------------------------------------------------------" 
			if [ \( `ls -alL ${INETD_CONF} 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 \) -a \( `ls -alL ${INETD_CONF} | grep '^-..-------' | wc -l` -eq 1 \) ]; then 
				RESULT="GOOD" 
				echo "[양호] ${INETD_CONF}의 소유자 및 권한 설정 양호" 
			elif [ `ls -alL ${INETD_CONF} 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 ]; then 
				RESULT="BAD" 
				#echo "[취약] ${INETD_CONF}의 권한 설정 미흡" 
				echo "[취약] "
			elif [ `ls -alL ${INETD_CONF} 2> /dev/null | grep '^-..-------' | wc -l` -eq 1 ]; then 
				RESULT="BAD" 
				#echo "[취약] ${INETD_CONF}의 소유자 설정 미흡"
				echo "[취약] "
			else
				RESULT="BAD" 
				#echo "[취약] ${INETD_CONF}의 소유자 및 권한 설정 미흡" 
				echo "[취약] "
			fi 
			echo "-----------------------------------------------------------------" 
		else 
			echo "파일이 존재하지 않음"
			echo "-----------------------------------------------------------------" 	
			RESULT="GOOD" 
			echo "[양호] ${INETD_CONF} 또는 ${XINETD_CONF} 파일이 존재하지 않음 " 
			echo "-----------------------------------------------------------------"
		fi 		
	} > $STATUS_FILE 2> /dev/null 
}

Unix_324(){
	{
		echo "양호: /etc/(r)syslog.conf 파일의 소유자가 root(또는 bin, sys)이고, 권한이 640 이하인 경우"
		echo "취약: /etc/(r)syslog.conf 파일의 소유자가 root(또는 bin, sys)가 아니거나, 권한이 640 이하가 아닌 경우"
	}  > $STANDARD_FILE
{ 
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_BadCase=0
		echo "-------------------------------------------------------------------"	
		PROCESS_CHECKER "syslogd"
		LS_Result=`PROCESS_CHECKER "syslogd"`
		if [ ${PCK} -eq 1 ]; then
			if [ `echo "${LS_Result}" | grep "rsyslog" | wc -l` -gt 0 ]; then
				echo "[ ${RSYSLOG_CONF} ]"
				if [ -f ${RSYSLOG_CONF} ]; then
						ls -alL ${RSYSLOG_CONF}
						echo ""
						if [ `ls -alL ${RSYSLOG_CONF} | grep '^-..-.-----' | wc -l` -eq 0 -o `ls -alL ${RSYSLOG_CONF} | awk '{print $3}' | grep -iE 'root|bin|sys' | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
				else
					LB_CheckCase1=1 
					echo "${RSYSLOG_CONF} FILE NOT FOUND"
					echo ""
				fi
			fi 
			
			if [ `echo "${LS_Result}" | grep -v "rsyslog" | grep -v "syslog-ng" | grep "syslog" | wc -l` -gt 0 ]; then
				echo "[ ${SYSLOG_CONF} ]"
					if [ -f ${SYSLOG_CONF} ]; then
						ls -alL ${SYSLOG_CONF}
						echo ""
						if [ `ls -alL ${SYSLOG_CONF} | grep '^-..-.-----' | wc -l` -eq 0 -o `ls -alL ${SYSLOG_CONF} | awk '{print $3}' | grep -iE 'root|bin|sys' | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
					else
						LB_CheckCase2=1  
						echo "${SYSLOG_CONF} FILE NOT FOUND"
						echo ""
					fi

			fi 
			
			if [ `echo "${LS_Result}" | grep -v "rsyslog" | grep "syslog-ng" | wc -l` -gt 0 ]; then
				echo "[ syslog-ng.conf ]"
					if [ -f ${SYSLOG_NG_CONF} ]; then
						LI_FileExist3=1
						ls -alL ${SYSLOG_NG_CONF}
						echo ""
						if [ `ls -alL ${SYSLOG_NG_CONF} | grep '^-..-.-----' | wc -l` -eq 0 -o `ls -alL ${SYSLOG_NG_CONF} | awk '{print $3}' | grep -iE 'root|bin|sys' | wc -l` -eq 0 ]; then
							LB_BadCase=1 
						fi
					else
						LB_CheckCase3=1 
					echo "${SYSLOG_NG_CONF} FILE NOT FOUND"
					echo ""
					fi
			fi
		else
			echo "[ syslogd ]"
			echo "syslogd IS DISABLED"
			echo ""
			
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${PCK}" -gt 0 ]; then
			if [ "${LB_BadCase}" -gt 0 ]; then
				echo "[취약]"
				RESULT="BAD"
			elif [ "${LB_CheckCase1}" -eq 1 ]; then 
				echo "[확인] ${RSYSLOG_CONF} 설정파일이 존재하지 않음"
				RESULT="CHECK"
			elif [ "${LB_CheckCase2}" -eq 1 ]; then 
				echo "[확인] ${SYSLOG_CONF} 설정파일이 존재하지 않음"
				RESULT="CHECK"
			elif [ "${LB_CheckCase3}" -eq 1 ]; then
				echo "[확인] ${SYSLOG_NG_CONF} 설정파일이 존재하지 않음"
				RESULT="CHECK"
			else
				echo "[양호] Log 설정 파일의 소유자 및 권한이 올바르게 설정되어 있음"
				RESULT="GOOD"
			fi
		else
			echo "[양호] syslogd가 구동 중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null 
}

Unix_325(){
	{
		echo "양호: DNS 서비스를 사용하지 않거나 주기적으로 패치를 관리하고 있는 경우" 
		echo "취약: DNS 서비스를 사용하며 주기적으로 패치를 관리하고 있지 않는 경우" 
	} > $STANDARD_FILE

	{
		#BIND 9 : 9.15.6, 9.14.8, 9.11.13, 9.11.13-S1
		#(2020.02) https://kb.isc.org/docs/aa-00913
		LB_CheckCase=0
						
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER named
		if [ ${PCK} -gt 0 ]; then
			echo "[ DNS Version ]"
			named -v
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase=1
			echo "[ named ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase=1
			echo "[ named ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ named ]"
			echo "DNS SERVICE NOT ACTIVATE"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${PCK}" -gt 0 ]; then
			echo "[인터뷰] DNS 패치를 주기적으로 관리하고 있는지 담당자에게 인터뷰"
			RESULT="CHECK"
		elif [ ${LB_CheckCase} -eq 1 ]; then
				echo "[인터뷰] DNS 패치를 주기적으로 관리하고 있는지 담당자에게 인터뷰"
				RESULT="CHECK"
		else
			echo "[양호] DNS 서비스가 구동 중이지 않음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_326(){
	{
		echo "양호 : /etc/passwd 파일의 소유자가 root이고, 권한이 644 이하인 경우"
		echo "취약 : /etc/passwd 파일의 소유자가 root가 아니거나, 권한이 644 이하가 아닌 경우"
	}  > $STANDARD_FILE

	{
		echo "-----------------------------------------------------------------"
		echo "[ /etc/passwd ]"
		if [ -f /etc/passwd ]; then
			ls -alL /etc/passwd
		else
			echo "/etc/passwd NOT FOUND"
		fi
		echo "-----------------------------------------------------------------"
		if [ -f /etc/passwd ]; then
			if [ \( `ls -alL /etc/passwd 2> /dev/null| awk '{print $3}' | grep -i root | wc -l` -eq 1 \) -a \( `ls -alL /etc/passwd | grep '^-..-.--.--' | wc -l` -eq 1 \) ]; then 
				RESULT="GOOD"
				echo "[양호] /etc/passwd 파일의 소유자 및 권한 설정 양호"
			elif [ `ls -alL /etc/passwd 2> /dev/null | awk '{print $3}' | grep -i root | wc -l` -eq 1 ]; then 
				RESULT="BAD"
				#echo "[취약] /etc/passwd 권한 설정 미흡"
				echo "[취약] "
			elif [ `ls -alL /etc/passwd 2> /dev/null | grep '^-..-.--.--' | wc -l` -eq 1 ]; then 
				RESULT="BAD"
				#echo "[취약] /etc/passwd 소유자 설정 미흡"
				echo "[취약] "
			else
				RESULT="BAD"
				#echo "[취약] /etc/passwd 소유자 및 권한 설정 미흡"
				echo "[취약] "
			fi
		else
			RESULT="CHECK"
			echo "[확인] /etc/passwd 파일이 존재하지 않음, 수동점검"
		fi
		echo "-----------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_327(){
	{		
		echo "양호: 세션 종료 시간이 600초(10분) 이하로 설정된 경우"
		echo "취약: 세션 종료 시간이 600초(10분) 이하로 설정되지 않은 경우"
	}  > $STANDARD_FILE

	{
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_GoodCase=0
		LB_BadCase=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"
		echo "[ USING SHELL ]"
		echo "${SHELL}"
		echo ""
		if [ `echo "${SHELL}" | grep -i bin/sh | wc -l` -gt 0 -o  `echo ${SHELL} | grep -i ksh | wc -l` -gt 0 -o `echo ${SHELL} | grep -i bash | wc -l` -gt 0 ]; then 
			for LS_File in ${GS_ProfileConf}; do
				echo "[ ${LS_File} file ]"
				if [ -e ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i "TMOUT" | grep -i "=" | wc -l` -gt 0 ]; then
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i "TMOUT"
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'export' | grep -i 'TMOUT' | wc -l` -eq 0 ]; then
							echo "export TMOUT NOT FOUND!"
							LB_BadCase=1
						elif [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'TMOUT' | awk -F"=" '{if ($2 > 0 && $2 <= 600) print $2}' | wc -l` -eq 0 ]; then
							LB_CheckCase1=1
						fi
					else
						echo "TMOUT OPTION NOT FOUND"
						LB_BadCase=1
					fi
				else
					echo "${LS_File} FILE NOT FOUND"
					LB_CheckCase2=1
				fi
				echo ""
				break
			done
		elif [ `echo "${SHELL}" | grep -i "csh\|tcsh" | wc -l ` -gt 0 ]; then
			for LS_File in ${GS_CshConf}; do
				echo "[ ${LS_File} file ]"
				if [ -e ${LS_File} ]; then	
					LI_FileExist=1
					if [ `cat "${LS_File}" | awk -F"#" '{print $1}' | grep -i "set autologout" | wc -l` -gt 0 ]; then
						cat "${LS_File}" | grep -i "set autologout"
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'set autologout' | awk -F"=" '{if ($2 > 0 && $2 <= 10) print $2}' | wc -l` -eq 1 ]; then
                        	LB_GoodCase=1
                    	fi
					else
						echo "autologout OPTION NOT FOUND"
						LB_BadCase=1
					fi
				fi
				echo ""
			done
			if [ "${LI_FileExist}" -eq 0 ]; then
				LB_CheckCase2=1
			fi
			if [ "${LB_GoodCase}" -eq 0 -a "${LB_BadCase}" -eq 0 ]; then
				LB_CheckCase1=1
			fi
		else
			echo "Shell : ${SHELL}"
			LB_CheckCase2=1
		fi
		echo ""
		echo "-------------------------------------------------------------------"
		if [ "${LB_CheckCase1}" -eq 1 ]; then
			echo "[확인] 세션 타임아웃이 내부 규정에 맞게 설정되어 있는지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ "${LB_CheckCase2}" -eq 1 ]; then
			echo "[확인] csh, bash, sh, ksh가 아닌 다른 쉘을 사용하거나 설정파일이 존재하지 않아 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ "${LB_BadCase}" -eq 1 ]; then
			echo "[취약] 세션 타임아웃 값이 설정되어 있지 않음"
			RESULT="BAD"
		else
			echo "[양호] 세션 타임아웃 값이 양호하게 설정되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

:<<'END'
Unix_328(){
	{
		echo "양호: Sendmail 버전이 최신버전인 경우" 
		echo "취약: Sendmail 버전이 최신버전이 아닌 경우" 
	} > $STANDARD_FILE
	{
		LB_GoodCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_CheckCase4=0
		LB_CheckCase5=0
		LI_FileExist=0
		echo "-------------------------------------------------------------------"

		PROCESS_CHECKER sendmail

		if [ ${PCK} -eq 1 ]; then
			echo "[ Sendmail Version ]"
			for LS_File in ${GS_SendmailConf}; do
				if [ -f ${LS_File} ]; then
					LI_FileExist=1
					if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | wc -l` -gt 0 ]; then 
						cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//'
						if [ `cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | grep '/' | wc -l` -gt 0 ]; then
							GS_SendmailVersion=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//' | awk -F"/" '{print $2}'`
							if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
								if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -eq 14 ]; then
									if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -le 9 ]; then
										LB_CheckCase5=1               
									fi
								elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 14 ]; then
									LB_CheckCase5=1
								fi
							elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
								LB_CheckCase5=1
							fi
						else
							GS_SendmailVersion=`cat ${LS_File} | awk -F"#" '{print $1}' | grep -i 'DZ' | sed 's/DZ//'`
							if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -eq 8 ]; then
								if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -eq 14 ]; then
									if [ `echo ${GS_SendmailVersion} | awk -F"." '{print $3}'` -le 9 ]; then
										LB_CheckCase5=1               
									fi
								elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $2}'` -lt 14 ]; then
									LB_CheckCase5=1
								fi
							elif [ `echo ${GS_SendmailVersion} | awk -F"." '{print $1}'` -lt 8 ]; then
								LB_CheckCase5=1
							fi
						fi
					else
						echo "Sendmail Version NOT FOUND"
						LB_CheckCase4=1
					fi
				fi
			done

			if [ ${LI_FileExist} -eq 0 ]; then
				echo "Sendmail Config File NOT FOUND"
				LB_CheckCase1=1
			fi
			echo ""
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ sendmail ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ sendmail ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ sendmail ]"
			echo "sendmail SERVICE NOT FOUND"
			echo ""
			LB_GoodCase=1
		fi

		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase5} -eq 1 ]; then
			echo "[확인] 취약한 버전의 SMTP 서비스 사용, 내부 규정을 수립하여 패치를 적용하고 있는지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase1} -eq 1 ]; then 
			echo "[확인] 확인할 수 없는 설정 파일이 존재하여 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase4} -eq 1 ]; then
			echo "[확인] SMTP 서비스의 버전을 확인할 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_GoodCase} -eq 1 ]; then
			echo "[양호] SMTP 서비스를 사용하지 않음"
			RESULT="GOOD"
		else
			echo "[양호] 양호한 버전의 SMTP 서비스를 사용함"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}
END

Unix_329(){
	{
		echo "양호: 로그 기록 정책이 정책에 따라 설정되어 수립되어 있으며, 보안정책에 따라 로그를 남기고 있을 경우('warning, information, notice' 레벨) " 
		echo "취약: 로그 기록 정책 미수립 또는, 정책에 따라 설정되어 있지 않거나 보안정책에 따라 로그를 남기고 있지 않을 경우" 
	} > $STANDARD_FILE
	

	{
		LB_CheckCase1=0		
		echo "-------------------------------------------------------------------"
		echo "[ /etc/syslog.conf ]"		
		if [ -f /etc/syslog.conf ]; then
			if [ `cat /etc/syslog.conf 2> /dev/null | grep -v '^#' | wc -l` -gt 0 ]; then
				LB_CheckCase1=1
				cat /etc/syslog.conf 2> /dev/null | grep -v '^#' | grep -v '^$'
				echo ""
			else
				LB_CheckCase1=1
				echo "/etc/syslog.conf CONTENTS EMPTY"
				echo ""
			fi
		else
			echo "/etc/syslog.conf NOT FOUND"
			echo ""
		fi
		
		echo "[ /etc/rsyslog.conf ]"		
		if [ -f /etc/rsyslog.conf ]; then
			if [ `cat /etc/rsyslog.conf 2> /dev/null | grep -v '^#' | wc -l` -gt 0 ]; then
				LB_CheckCase1=1
				cat /etc/rsyslog.conf 2> /dev/null | grep -v '^#' | grep -v '^$'
				echo ""
			else
				LB_CheckCase1=1
				echo "/etc/rsyslog.conf CONTENTS EMPTY"
				echo ""
			fi
			#8.33 이상버전에서 include 확인
			if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 1p` -ge 8 ]; then
				if [ `rsyslogd -v | grep 'compiled with' | grep -o '[0-9]\+' | sed -n 2p` -ge 33 ]; then
					if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | wc -l` -gt 0 ]; then
						file_name=`cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -E 'include\([^)]*\)' | grep -oP 'file="\K[^"]+'`
						file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
						#파일이 존재할 경우
						echo ""
						echo "[ ls -a $file_name ]"
						if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' |wc -l` -gt 0 ]; then
							ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
							for file in ${file_list}; do
								echo ""
								echo "[ $file ]"
								cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
								LB_CheckCase=1
							done
						else
							echo $file_name " : conf file does not exist"
							echo ""
						fi
					fi
				fi
			fi
			
			#includeconfig
			if [ `cat /etc/rsyslog.conf | awk -F "#" '{print $1}' | grep -i '^\s*\$IncludeConfig' | wc -l` -gt 0 ]; then
				file_name=`cat /etc/rsyslog.conf | awk -F '#' '{print $1}' | grep -i '^\s*\$IncludeConfig' | awk '{print $2}'`
				file_list=`ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'`
				echo ""
				echo "[ ls -a $file_name ]"
				#파일이 존재할 경우
				if [ `ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$' | wc -l` -gt 0 ]; then
					ls -a ${file_name} | grep -vE '^\..*\s+\.$|^\..*\s+\.\.$'
					for file in ${file_list}; do
						echo ""
						echo "[ $file ]"
						cat ${file} | awk -F "#" '{print $1}' | sed '/^$/d'
						LB_CheckCase=1
					done
				else
					echo $file_name " : conf file does not exist"
					echo ""
				fi
			fi
		else
			echo "/etc/rsyslog.conf NOT FOUND"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
			if [ "${LB_CheckCase1}" -gt 0 ]; then
				echo "[확인] 로그가 내부 정책에 맞게 설정 되어 있는지 확인 필요"
				RESULT="CHECK"
			else
				echo "[확인] 설정 파일이 존재하지 않음"
				RESULT="CHECK"
			fi	
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_330(){
	{
		echo "양호: 시스템 관리나 운용에 불필요한 그룹이 삭제되어 있는 경우" 
		echo "취약: 시스템 관리나 운용에 불필요한 그룹이 존재할 경우"	
	} > $STANDARD_FILE
	
	{
	LB_CheckCase=0
	echo "-------------------------------------------------------------------"
	if [ -f /etc/group ]; then
		echo "[ /etc/group ]"
		cat /etc/group

		echo ""
		echo "[ /etc/passwd ]"
		if [ -f /etc/passwd ]; then
			cat /etc/passwd
		else
			LB_CheckCase=1
			echo "/etc/passwd FILE NOT FOUND"
		fi
	else
		LB_CheckCase=1
		echo "[ /etc/group ]"
		echo "/etc/group FILE NOT FOUND"
	fi

	echo "-------------------------------------------------------------------"
	if [ "${LB_CheckCase}" -gt 0 ]; then
		echo "[확인] 설정 파일이 존재하지 않음"
		RESULT="CHECK"
	else
		echo "[확인] 시스템 관리나 운용에 불필요한 그룹이 존재하는지 확인"
		RESULT="CHECK"
	fi
	echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_331(){ 
	{ 
		echo "양호: root 계정과 동일한 UID를 갖는 계정이 존재하지 않는 경우" 
		echo "취약: root 계정과 동일한 UID를 갖는 계정이 존재하는 경우"  
	} > $STANDARD_FILE 
	 
	{	 
		echo "-------------------------------------------------------------------" 
		echo "[ UID LIST ]" 
		if [ `cat ${GS_PasswdConf} | awk -F':' '{print $3}' | grep -w 0 | wc -l` -ge 1 ];	then 
			awk -F':' '$3==0 { print $1 " -> UID=" $3 }' ${GS_PasswdConf} 
		else 
			echo "UID가 0인 계정이 존재하지 않음" 
		fi 
 
		if [ `awk -F: '$3==0  { print $1 }' ${GS_PasswdConf} | grep -v "root" | wc -l` -eq 0 ] 
		then 
			CASE=1 
		else 
			CASE=2 
		fi 
				 
		echo "-------------------------------------------------------------------" 
		if [ "${CASE}" -eq 1 ]; then 
			echo "[양호] root 와 동일한 UID로 설정된 사용자 계정이 존재하지 않음" 
			RESULT="GOOD" 
		elif [ "${CASE}" -eq 2 ]; then 
			#echo "[취약] root 와 동일한 UID로 설정된 사용자 계정이 존재함"
			echo "[취약] "
			RESULT="BAD"
		fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

Unix_332(){
	{
		echo "양호: Finger 서비스가 비활성화 되어 있는 경우" 
		echo "취약: Finger 서비스가 활성화 되어 있는 경우" 
	} > $STANDARD_FILE	
	{
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		echo "-------------------------------------------------------------------"
		
		PROCESS_CHECKER finger

		if [ ${PCK} -eq 1 ]; then
			LB_BadCase=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase1=1
			echo "[ finger ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ finger ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ finger ]"
			echo "finger SERVICE NOT ACTIVATE"
			echo ""
		fi
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] "
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
	        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] finger 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_333(){
	{
		echo "양호 : crontab 명령어 일반사용자 금지 및 crond 관련 파일 640 이하인 경우"
		echo "취약 : crontab 명령어 일반사용자 사용가능하거나 crond 관련 파일 640 이상인 경우" 
	} > $STANDARD_FILE 2> /dev/null

	{
		LI_FileExist=0
		LI_DirExist=0
		LB_BadCase=0
		LB_CheckCase1=0

		echo "-------------------------------------------------------------------"
		LS_CronFiles="/etc/crontab /etc/cron.allow /etc/cron.deny /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly"


		echo "[ /usr/bin/crontab ]"
		if [ -f /usr/bin/crontab ]; then
			ls -al /usr/bin/crontab	2> /dev/null		
			if [ `ls -al /usr/bin/crontab 2> /dev/null | grep '^.....-.---' | wc -l` -eq 0  -o `ls -al /usr/bin/crontab | awk '{print $3}' | grep "root" | wc -l` -eq 0 ]; then
				LB_BadCase=1
			fi
		else
			echo "FILE NOT FOUND"
			LB_CheckCase1=1
		fi
		echo ""
		
		echo "[ Cron FILE ]"
		for LS_File1 in ${LS_CronFiles}; do
			if [ -f ${LS_File1} ]; then
				LI_FileExist=1
				ls -al ${LS_File1} 2> /dev/null
				if [ `ls -al ${LS_File1} 2> /dev/null | grep '^...-.-----' | wc -l` -eq 0 -o `ls -al ${LS_File1} | awk '{print $3}' | grep "root" | wc -l` -eq 0 ]; then
					LB_BadCase=1
				fi
			fi
		done
		if [ ${LI_FileExist} -eq 0 ]; then
			echo "CRON FILE NOT FOUND"
		fi
		echo ""

		if [ -d /var/spool/cron/crontabs ]; then
			LS_CronTaskList=`ls -al /var/spool/cron/crontabs/* 2> /dev/null | awk '{print $9}'`
		elif [ -d /var/spool/cron ]; then
			LS_CronTaskList=`ls -al /var/spool/cron/* 2> /dev/null | awk '{print $9}'`
		else
			echo "[ Crond Task List ]"
			echo "CONTENT EMPTY"
			echo ""
		fi
		
		if [ `echo "${LS_CronTaskList}" | wc -w` -gt 0 ]; then
			echo "[ Crond Task List ]"
			for LS_File2 in ${LS_CronTaskList}; do
				if [ -f ${LS_File2} ]; then
					ls -al ${LS_File2} 2> /dev/null
					if [ `ls -al ${LS_File2} 2> /dev/null | grep '^...-.-----' | wc -l` -eq 0 -o `ls -al ${LS_File2} | awk '{print $3}' | grep "root" | wc -l` -eq 0]; then
						LB_BadCase=1
					fi
				fi
			done
		fi
		
		echo "-------------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LB_CheckCase1}" -eq 1 ]; then 
			echo "[확인] /usr/bin/crontab 파일이 존재하지 않음"
			RESULT="CHECK"
		else 
			echo "[양호] crontab 명령어 및 관련 파일 권한 양호하게 설정되어 있음" 
			RESULT="GOOD"
		fi			
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE  2> /dev/null
}
Unix_334(){
	{
		echo "양호: 사용하지 않는 DoS 공격에 취약한 서비스가 비활성화 된 경우" 
		echo "취약: 사용하지 않는 DoS 공격에 취약한 서비스가 활성화 된 경우"  
	} > $STANDARD_FILE	
	{
		LS_DosServices="echo-stream echo-dgram discard-stream discard-dgram daytime-stream daytime-dgram chargen-stream chargen-dgram"
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		echo "-------------------------------------------------------------------"
		for LS_Service in ${LS_DosServices}; do
		
			PROCESS_CHECKER ${LS_Service}
			
			INETDON=0
			
			if [ ${PCK} -eq 1 ]; then
				LB_CheckCase1=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase3=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} 서비스가 구동중이지 않음"
				echo ""
			fi
		done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] DDoS 공격에 취약한 서비스가 활성화되어 있어 사용하고 있는 서비스인지 담당자와 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase3} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] DDoS 공격에 취약한 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_335(){
	{
		echo "양호: automountd 서비스가 비활성화 되어 있는 경우" 
		echo "취약: automountd 서비스가 활성화 되어 있는 경우" 
	} > $STANDARD_FILE
	{
		#LS_AutomountServices="automount autofs"
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		echo "-------------------------------------------------------------------"
		#for LS_Service in ${LS_AutomountServices}; do
		PROCESS_CHECKER "automount" ""
		INETDON=0
			
		if [ ${PCK} -eq 1 ]; then
			LB_BadCase=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase1=1
			echo "[ automount ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ automount ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			echo "[ automount ]"
			echo "automount 서비스가 구동중이지 않음"
			echo ""
		fi
			
		PROCESS_CHECKER "" "autofs"
		
		if [ ${PCK} -eq 1 ]; then
			LB_BadCase=1
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase1=1
			echo "[ autofs ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ autofs ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""			
		fi
		#done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] automount(autofs) 서비스 활성화"
			RESULT="BAD"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] automount(autofs) 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_336(){
	{
		echo "양호: tftp, talk, ntalk 서비스가 비활성화 되어 있는 경우" 
		echo "취약: tftp, talk, ntalk 서비스가 활성화 되어 있는 경우" 
	} > $STANDARD_FILE
	{
		LS_TServices="tftp talk ntalk"
		LB_BadCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		echo "-------------------------------------------------------------------"
		for LS_Service in ${LS_TServices}; do
		
			PROCESS_CHECKER ${LS_Service}
			
			INETDON=0
			
			if [ ${PCK} -eq 1 ]; then
				LB_BadCase=1
			elif [ ${INETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase1=1
				echo "[ ${LS_Service} ]"
				echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
				echo ""
			elif [ ${XINETD_CONFGCK} -eq 2 ]; then
				LB_CheckCase2=1
				echo "[ ${LS_Service} ]"
				echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
				echo ""
			else
				echo "[ ${LS_Service} ]"
				echo "${LS_Service} 서비스가 구동중이지 않음"
				echo ""
			fi
		done
		
		INETDON=1
		
		echo "-------------------------------------------------------------------"
		if [ ${LB_BadCase} -eq 1 ]; then
			echo "[취약] tftp, talk, ntalk 서비스 활성화"
			RESULT="CHECK"
		elif [ ${LB_CheckCase1} -eq 1 ]; then
			echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		elif [ ${LB_CheckCase2} -eq 1 ]; then
			echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] tftp, talk, ntalk 서비스 비활성화"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_337(){
	{
		echo "양호: ftp 계정에 /bin/false나 /sbin/nologin 쉘이 부여되어 있는 경우"
		echo "취약: ftp 계정에 /bin/false와 /sbin/nologin 쉘이 부여되어 있지 않은 경우" 
	} > $STANDARD_FILE
	
	{
		echo "-------------------------------------------------------------------"
		echo "[ FTP Service Process ]"
			if [ `ps -ef | grep -v grep | grep -i 'ftp' | wc -l` -eq 0 ]; then
				if [ `netstat -an | grep ':21 ' | wc -l` -eq 0 ]; then
					echo "FTP 서비스가 구동중이지 않음"
				fi
				echo "-------------------------------------------------------------------"
				echo "[양호] ftp 서비스가 구동중이지 않음"
				RESULT="GOOD"
				echo "-------------------------------------------------------------------"
			else
				ps -ef | grep -v grep | grep -i 'ftp'
				echo ""
			
				echo " [ ${GS_PasswdConf} ]"
				if [ `cat ${GS_PasswdConf} | grep -w '^ftp' | wc -l` -ge 1 ]; then
					cat ${GS_PasswdConf} | grep -w '^ftp'
				else
					echo "FTP ACCOUNT NOT FOUND"
				fi	
				echo "-------------------------------------------------------------------"
				if [ `cat ${GS_PasswdConf} | awk -F':' '$1=="ftp" {print $7}' | grep '/bin/false' | wc -l` -ge 1 ]; then
					echo "[양호] ftp 계정에 /bin/false 쉘이 부여되어 있으며 ftp 계정으로 Console로 접속이 불가"
					RESULT="GOOD"
				elif [ `cat ${GS_PasswdConf} | awk -F':' '$1=="ftp" {print $7}' | grep '/sbin/nologin' | wc -l` -ge 1 ]; then
					echo "[양호] ftp 계정에 /sbin/nologin 쉘이 부여되어 있으며 ftp 계정으로 Console로 접속이 불가"
					RESULT="GOOD"
				elif [ `cat ${GS_PasswdConf} | grep -w '^ftp' | wc -l` -ge 0 ]; then
					echo "[양호] ftp 계정이 존재하지 않음"
					RESULT="GOOD"
				else
					#echo "[취약] ftp 계정에 /bin/false와 /sbin/nologin이 부여되어 있지 있지 않아 ftp 계정으로 로그인 가능"
					echo "[취약] "
					RESULT="BAD"
				fi
				echo "-------------------------------------------------------------------"
			fi
	} > $STATUS_FILE
}

Unix_338(){
	{
		echo "양호 : at 명령어 일반사용자 금지 및 at 관련 파일 640 이하인 경우"
		echo "취약 : at 명령어 일반사용자 사용가능하거나, at 관련 파일 640 이상인 경우"
	} > $STANDARD_FILE
	
	{
		LB_BadCase=0
		LI_FileExist1=0
		LI_FileExist2=0
		echo "-------------------------------------------------------------------"
		echo "[ at PERMISSION ]"
		if [ -f /usr/bin/at ]; then
			LI_FileExist1=1
			ls -al /usr/bin/at 2> /dev/null	
			if [ `ls -al /usr/bin/at 2> /dev/null | grep '^-....-.---' | wc -l` -eq 0 ]; then
				LB_BadCase=1
			fi
		else
			echo "\'at\' COMMAND NOT FOUND"		
		fi
		echo ""
		
		for FILE in ${AT_FILE}; do
			echo "[ ${FILE} Permission ]"
			if [ -f ${FILE} ]; then
				LI_FileExist2=1
				ls -al ${FILE} 2> /dev/null	
				if [ `ls -al ${FILE} 2> /dev/null | grep '^-..-.-----' | wc -l` -eq 0 ]; then
					LB_BadCase=1
				fi
			else
				echo "FILE NOT FOUND"
			fi
			echo ""
		done
		
		echo "-------------------------------------------------------------------"
		if [ "${LB_BadCase}" -gt 0 ]; then
			echo "[취약]"
			RESULT="BAD"
		elif [ "${LI_FileExist1}" -gt 0 -o "${LI_FileExist2}" -gt 0 ]; then
			echo "[양호] at 명령어 일반사용자 금지 및 at 관련 파일 640 이하" 
			RESULT="GOOD"
		else 
			echo "[양호] at 명령어를 사용하지 않거나, 접근제어 파일이 존재하지 않음" 
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE 2> /dev/null
}
Unix_339(){ 
	{  
		echo "양호 : su 명령어를 특정 그룹에 속한 사용자만 사용하도록 제한 되어 있는 경우"
		echo "※ 일반사용자 계정 없이 root 계정만 사용하는 경우 su 명령어 사용제한 불필요"
		echo "취약 : su 명령어를 모든 사용자가 사용하도록 되어 있는 경우"	
	} > $STANDARD_FILE 
	 
	{					 
		#pam_wheel에 trust 있으면 무조건 취약 
		#required, requisite가 pam_wheel 모듈에 설정되어야 양호함 
		LB_CheckCase=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LB_BadCase=0
		GROUP_CHECK=0
		GROUP_CHECK2=0
		echo "-------------------------------------------------------------------" 
		echo "[ su 명령어 pam 설정 (/etc/pam.d/su) ]" 
		if [ -f /etc/pam.d/su ]; then

			if [ `cat /etc/pam.d/su | awk -F"#" '{print $1}' | grep "pam_wheel.so" | grep "required" | grep "use_uid" | wc -l` -gt 0 ]; then  
				if [ `ls -alL ${SU_BIN} | awk '{print $4}'` != "wheel" ]; then
					LB_CheckCase2=1
				fi
				cat /etc/pam.d/su |awk -F"#" '{print $1}' | sed '/^$/d' | grep -i pam_wheel.so
			elif [ `cat /etc/pam.d/su | awk -F"#" '{print $1}' | grep "pam_wheel.so" | grep "required" | grep "debug" | wc -l` -gt 0 ]; then  
				GROUP_CHECK=1
				if [ `cat /etc/pam.d/su | awk -F"#" '{print $1}' | grep "pam_wheel.so" | grep "required" | grep "debug" | awk -F"=" '{print $2}'` == `ls -alL ${SU_BIN} | awk '{print $4}'` ]; then
					``
				else
					LB_CheckCase2=1
				fi
				cat /etc/pam.d/su |awk -F"#" '{print $1}' | sed '/^$/d' | grep -i pam_wheel.so
			else
				echo "OPTION NOT FOUND"
				GROUP_CHECK2=1
			fi
		else 
			echo "/etc/pam.d/su FILE NOT FOUND" 
			LB_CheckCase=1
		fi 
		echo ""
		 

		echo "[ su 파일 실행 권한 - ${SU_BIN} ]"
		if [ -f ${SU_BIN} ]; then
			if [ `ls -alL ${SU_BIN} | awk '{print $1}'  | grep '^-....-.---' | wc -l` -eq 0 ]; then 
				ls -ald ${SU_BIN}
				LB_BadCase=1
			else
				ls -ald ${SU_BIN}	
			fi
		else
			echo "${SU_BIN} FILE NOT FOUND" 
			LB_CheckCase=1
		fi		
		echo ""
		echo "[ pam 및 su 그룹 사용자 목록 ]"
		if [ "${GROUP_CHECK}" -gt 0 ]; then
			com=`cat /etc/pam.d/su | awk -F"#" '{print $1}' | grep "pam_wheel.so" | grep "required" | grep "debug" | awk -F"=" '{print $2}'`
			if [ `cat ${GROUP_CONF} | grep -i "${com}" | wc -l` -gt 0 ]; then	
				echo `cat ${GROUP_CONF} | grep -i "${com}"`
				if [ `cat ${GROUP_CONF} | grep -i "${com}" | awk -F":" '{print $4}' | wc -L` -eq 0 ]; then
					if [ `ls -al /usr/bin/su | awk -F" " '{print $4}'` != "root" ]; then
						LB_BadCase=1
					fi
				fi
			else
				echo "${com} 그룹이 존재하지 않음"
			fi
		elif [ "${GROUP_CHECK2}" -eq 0 -a `cat ${GROUP_CONF} | grep -i "wheel" | wc -l` -gt 0 ]; then
			if [ `cat ${GROUP_CONF} | grep -i "wheel" | awk -F":" '{print $4}' | wc -L` -gt 0 ]; then	
				echo `cat ${GROUP_CONF} | grep -i "wheel"`
			else
				echo "*wheel 그룹 구성원이 존재하지 않음*"
				echo `cat ${GROUP_CONF} | grep -i "wheel"`
				LB_BadCase=1
			fi
		else
			if [ `ls -alL ${SU_BIN} | awk '{print $4}'` != "root" ]; then
					LB_CheckCase3=1
			fi
			cat /etc/group | grep -i `ls -al /usr/bin/su | awk -F" " '{print $4}'`
		fi
		echo ""
		# pam_wheel=`cat /etc/pam.d/su | awk -F'#' '{print $1}' | grep -i pam_wheel.so | grep -i -v sufficient | grep -i -v optional | grep -i use_uid` 
		# su_groups=`echo ${pam_wheel} | awk 'BEGIN{IGNORECASE=1} { for (i = 1; i <= NF; i++){ if( $i ~ /group=.+/ ){print $i}} }' | awk -F'=' '{print $2}'` 
		  
		# echo "[ pam_wheel에 지정된 그룹의 멤버 - ${GROUP_CONF} ]" 
		# if [ -f ${GROUP_CONF} ]; then 
		# 	if [ `echo ${pam_wheel} | awk '$0 ~ /[\s]+/ { print $0 }' | wc -l` -gt 0 ]; then 
		# 		if [ `echo "${su_groups}"| awk '$0 ~ /[\s]+/ { print $0 }' | wc -l` -gt 0 ]; then 
		# 			cat ${GROUP_CONF} | grep ${su_groups} 
		# 		else 
		# 			cat ${GROUP_CONF} | grep "wheel" 
		# 		fi 
		# 	else 
		# 		echo "pam_wheel 모듈 설정이 되어있지 않음" 
		# 	fi 
		# else 
		# 	echo "${GROUP_CONF} FILE NOT FOUND" 
		# fi			 
		  
		 
		echo "-------------------------------------------------------------------" 
		if [ "${LB_BadCase}" -gt 0 ]; then 
			echo "[취약] "
			RESULT="BAD"
		elif [ "${LB_CheckCase}" -gt 0 ]; then 
			echo "[확인] 설정파일 경로 확인 필요" 
			RESULT="CHECK" 
		elif [ "${LB_CheckCase2}" -gt 0 ]; then
			echo "[확인] /etc/pam.d/su 모듈에 정의된 그룹과 ${SU_BIN} 명령어 사용 그룹이 상이함"
			RESULT="CHECK"
		elif [ "${LB_CheckCase3}" -gt 0 ]; then
			echo "[확인] 그룹에 불필요한 구성원이 있는지 인터뷰 필요"
			RESULT="CHECK"
		else 
			echo "[양호] pam_wheel.so 모듈 설정으로 특정 그룹에 속한 사용자만 SU 명령어를 사용하도록 제한되어 있고 일반 사용자가 명령어를 사용할 수 없도록 권한 설정이 적절하게 되어 있음" 
			RESULT="GOOD" 
		fi 
		echo "-------------------------------------------------------------------" 
	} > $STATUS_FILE 
} 

Unix_340(){
	{
		echo "양호: SNMP Community String이 public, private이 아닌 경우"
		echo "취약: SNMP Community String이 public, private인 경우"
	}  > $STANDARD_FILE

	{
		LB_BadCase=0
		LB_GoodCase=0
		LB_CheckCase1=0
		LB_CheckCase2=0
		LB_CheckCase3=0
		LI_FileExist=0
		CNT=0
		CASE=0
		FLAG=0
		echo "-------------------------------------------------------------------"
		PROCESS_CHECKER snmpd
		if [ "${PCK}" -gt 0 ]; then
			if [ `snmpd -v 2> /dev/null | sed '/^$/d' | wc -l` -gt 0 ]; then
				echo ""
				echo "[ SNMPD Version ]"
				snmpd -v | sed '/^$/d'
			fi

			for FILE in ${SNMPD_CONF_LIST}; do
				if [ -f ${FILE} ]; then
					LI_FileExist=1
					if [ `cat ${FILE} | grep -v '^#' | grep '^com2sec' | wc -l` -ge 1 ]; then
						if [ `cat ${FILE} | grep '^com2sec' | grep -i 'public' | wc -l` -ge 1 -o `cat ${FILE} | grep '^com2sec' | grep -i 'private' | wc -l` -ge 1 ]; then
							LB_BadCase=1
						fi
					fi
					if [ `cat ${FILE} | grep -v '^#' | grep -ie '^rocommunity' -ie '^rwcommunity' | wc -l` -ge 1 ]; then
						if [ `cat ${FILE} | grep -v '^#' | grep -ie '^rocommunity' -ie '^rwcommunity' | grep -i 'public' | wc -l` -ge 1 -o `cat ${FILE} | grep -v '^#' | grep -ie '^rocommunity' -ie '^rwcommunity' | grep -i 'private' | wc -l` -ge 1 ]; then
							LB_BadCase=1
						fi
					fi

					echo ""
					echo "[ SNMPD Community String (${FILE}) ]"
					if [ `cat ${FILE} | grep -v "^#" | grep -i '^com2sec' | wc -l` -gt 0 -o `cat ${FILE} | grep -v '^#' | grep -ie '^rocommunity' -ie '^rwcommunity' | wc -l` -gt 0 ]; then
						cat ${FILE} | grep -v "^#" | grep -i '^com2sec'
						cat ${FILE} | grep -v '^#' | grep -ie '^rocommunity' -ie '^rwcommunity'
					else
						echo "${FILE} - COMMUNITY STRING NOT FOUND"
					fi
					

				fi
			done

			if [ "${LI_FileExist}" -eq 0 ]; then
				LB_CheckCase1=1
			fi 
		elif [ ${INETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase2=1
			echo "[ SNMP ]"
			echo "inetd SERVICE ACTIVE, inetd.conf FILE NOT FOUND."
			echo ""
		elif [ ${XINETD_CONFGCK} -eq 2 ]; then
			LB_CheckCase3=1
			echo "[ SNMP ]"
			echo "xinetd SERVICE ACTIVE, xinetd.conf FILE NOT FOUND."
			echo ""
		else
			LB_GoodCase=1
			echo "[ SNMP ]"
			echo "SNMP SERVICE NOT ACTIVATE"
			echo ""
		fi

		echo ""
		echo "-------------------------------------------------------------------"
			if [ ${LB_BadCase} -eq 1 ]; then
				echo "[취약]"
				RESULT="BAD"
			elif [ ${LB_CheckCase1} -eq 1 ]; then
				echo "[확인] Config경로 확인"
				RESULT="CHECK"
			elif [ ${LB_CheckCase2} -eq 1 ]; then
		        echo "[확인] INETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		        RESULT="CHECK"
		    elif [ ${LB_CheckCase3} -eq 1 ]; then
		        echo "[확인] XINETD가 구동중이나 Config 파일을 찾을 수 없어 담당자와의 인터뷰 필요"
		        RESULT="CHECK"
		    elif [ ${LB_GoodCase} -eq 0 ]; then
		        echo "[확인] SNMP Community String의 10자리 이상 또는 영문자, 숫자, 특수문자 포함 8자리 이상의 복잡도가 만족되는지 확인"
				RESULT="CHECK"
			else
				echo "[양호] SNMP 서비스가 구동중이지 않음"
				RESULT="GOOD"
			fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_341(){
	{
		echo "양호: SHA-2 이상의 안전한 비밀번호 암호화 알고리즘을 사용하는 경우"
		echo "취약: 취약한 비밀번호 암호화 알고리즘을 사용하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_GoodCase=0
		echo "-------------------------------------------------------------------"
		echo "[ /etc/shadow 암호화 알고리즘 확인 ]"

		if [ -f /etc/shadow ]; then
			# 잠긴 계정(!,$6$...), 비활성계정(!!,*) 제외, 실제 로그인 가능한 계정만 점검
			WEAK_HASH=$(awk -F: '$2 != "" && $2 != "!" && $2 != "!!" && $2 != "*" && $2 !~ /^!\$/ && $2 !~ /^\$[56]\$/ && $2 !~ /^\$y\$/ {print $1}' /etc/shadow 2>/dev/null)
			if [ -n "$WEAK_HASH" ]; then
				echo "[취약] SHA-2 미만의 암호화 알고리즘을 사용하는 계정 존재"
				echo "$WEAK_HASH"
				LB_BadCase=1
			else
				echo "[양호] 모든 계정이 SHA-256(\$5\$) 또는 SHA-512(\$6\$) 사용"
				LB_GoodCase=1
			fi
		else
			echo "[확인] /etc/shadow 파일이 존재하지 않음"
			LB_BadCase=1
		fi

		echo ""
		echo "[ /etc/login.defs ENCRYPT_METHOD 확인 ]"
		if [ -f /etc/login.defs ]; then
			grep -i "^ENCRYPT_METHOD" /etc/login.defs 2>/dev/null
			ENCRYPT_METHOD=$(grep -i "^ENCRYPT_METHOD" /etc/login.defs 2>/dev/null | awk '{print $2}')
			if [ -n "$ENCRYPT_METHOD" ]; then
				if echo "$ENCRYPT_METHOD" | grep -qi "SHA256\|SHA512"; then
					echo "[양호] ENCRYPT_METHOD: $ENCRYPT_METHOD"
				else
					echo "[취약] ENCRYPT_METHOD: $ENCRYPT_METHOD (SHA256 또는 SHA512 권장)"
					LB_BadCase=1
				fi
			else
				echo "[확인] ENCRYPT_METHOD 설정 없음"
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] 취약한 비밀번호 암호화 알고리즘 사용"
			RESULT="BAD"
		else
			echo "[양호] 안전한 비밀번호 암호화 알고리즘 사용"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_342(){
	{
		echo "양호: 시스템 시작 스크립트 파일의 소유자가 root이고, 일반 사용자의 쓰기 권한이 제거된 경우"
		echo "취약: 시스템 시작 스크립트 파일의 소유자가 root가 아니거나, 일반 사용자의 쓰기 권한이 부여된 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		echo "-------------------------------------------------------------------"
		echo "[ 시스템 시작 스크립트 권한 점검 ]"

		for DIR in /etc/rc.d/rc*.d /etc/rc*.d /etc/init.d; do
			if [ -d "$DIR" ]; then
				echo ""
				echo "** ${DIR} **"
				BAD_FILES=$(find "$DIR" -type f \( ! -user root -o -perm -002 -o -perm -020 \) 2>/dev/null)
				if [ -n "$BAD_FILES" ]; then
					echo "[취약] 소유자가 root가 아니거나 일반 사용자 쓰기 권한이 부여된 파일:"
					echo "$BAD_FILES" | while read f; do ls -l "$f" 2>/dev/null; done
					LB_BadCase=1
				else
					echo "[양호] 권한 설정 적절"
				fi
			fi
		done

		# systemd 환경
		if [ -d /etc/systemd/system ]; then
			echo ""
			echo "** /etc/systemd/system **"
			BAD_SYSD=$(find /etc/systemd/system -maxdepth 2 -type f \( ! -user root -o -perm -002 -o -perm -020 \) 2>/dev/null)
			if [ -n "$BAD_SYSD" ]; then
				echo "[취약] 소유자가 root가 아니거나 일반 사용자 쓰기 권한이 부여된 파일:"
				echo "$BAD_SYSD" | while read f; do ls -l "$f" 2>/dev/null; done
				LB_BadCase=1
			else
				echo "[양호] 권한 설정 적절"
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] 시스템 시작 스크립트 권한 설정 미흡"
			RESULT="BAD"
		else
			echo "[양호] 시스템 시작 스크립트 권한 설정 적절"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_343(){
	{
		echo "양호: DNS 동적 업데이트 기능이 비활성화되었거나, 활성화 시 적절한 접근통제를 수행하는 경우"
		echo "취약: DNS 동적 업데이트 기능이 활성화 중이며 적절한 접근통제를 수행하지 않는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ DNS 동적 업데이트 설정 점검 ]"

		PROCESS_CHECKER named

		if [ ${PCK} -eq 1 ]; then
			NAMED_CONF=""
			for CONF in /etc/named.conf /etc/bind/named.conf /etc/named/named.conf; do
				if [ -f "$CONF" ]; then
					NAMED_CONF="$CONF"
					break
				fi
			done

			if [ -n "$NAMED_CONF" ]; then
				echo "[ $NAMED_CONF ]"
				cat "$NAMED_CONF"
				echo ""
				ALLOW_UPDATE=$(grep -i "allow-update" "$NAMED_CONF" 2>/dev/null)
				if [ -n "$ALLOW_UPDATE" ]; then
					if echo "$ALLOW_UPDATE" | grep -q "none"; then
						echo "[양호] allow-update { none; } 설정됨"
					elif echo "$ALLOW_UPDATE" | grep -q "any"; then
						echo "[취약] allow-update { any; } 설정됨 (모든 호스트 허용)"
						LB_BadCase=1
					else
						echo "[확인] allow-update 설정 확인 필요"
						echo "$ALLOW_UPDATE"
						LB_CheckCase=1
					fi
				else
					echo "[양호] allow-update 설정 없음 (기본 비활성화)"
				fi
			else
				echo "[확인] named.conf 파일을 찾을 수 없음"
				LB_CheckCase=1
			fi
		else
			echo "[양호] DNS 서비스가 구동중이지 않음"
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] DNS 동적 업데이트 접근통제 미설정"
			RESULT="BAD"
		elif [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] 담당자와의 인터뷰 필요"
			RESULT="CHECK"
		else
			echo "[양호] DNS 동적 업데이트 설정 적절"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_344(){
	{
		echo "양호: 원격 접속 시 Telnet 프로토콜을 비활성화하고 있는 경우"
		echo "취약: 원격 접속 시 Telnet 프로토콜을 사용하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		echo "-------------------------------------------------------------------"
		echo "[ Telnet 서비스 구동 점검 ]"

		PROCESS_CHECKER telnetd
		TELNET_PROC=${PCK}
		PROCESS_CHECKER in.telnetd
		TELNET_PROC2=${PCK}

		if [ $TELNET_PROC -eq 1 ] || [ $TELNET_PROC2 -eq 1 ]; then
			echo "[취약] Telnet 서비스가 구동중"
			LB_BadCase=1
		else
			echo "[양호] Telnet 프로세스 미구동"
		fi

		echo ""
		# inetd 확인
		if [ -f /etc/inetd.conf ]; then
			echo "[ /etc/inetd.conf ]"
			TELNET_INETD=$(grep -v "^#" /etc/inetd.conf 2>/dev/null | grep -i "telnet")
			if [ -n "$TELNET_INETD" ]; then
				echo "[취약] inetd.conf에 telnet 활성화"
				echo "$TELNET_INETD"
				LB_BadCase=1
			else
				echo "[양호] inetd.conf에 telnet 비활성화 또는 미설정"
			fi
		fi

		# xinetd 확인
		if [ -f /etc/xinetd.d/telnet ]; then
			echo "[ /etc/xinetd.d/telnet ]"
			cat /etc/xinetd.d/telnet
			DISABLE=$(grep -i "disable" /etc/xinetd.d/telnet 2>/dev/null | grep -i "yes")
			if [ -z "$DISABLE" ]; then
				echo "[취약] xinetd telnet 서비스 활성화"
				LB_BadCase=1
			else
				echo "[양호] xinetd telnet 서비스 비활성화"
			fi
		fi

		# systemd 확인
		TELNET_SOCKET=$(systemctl is-enabled telnet.socket 2>/dev/null)
		if [ "$TELNET_SOCKET" = "enabled" ]; then
			echo "[취약] telnet.socket 서비스 활성화"
			LB_BadCase=1
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] Telnet 서비스가 활성화되어 있음"
			RESULT="BAD"
		else
			echo "[양호] Telnet 서비스가 비활성화되어 있음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_345(){
	{
		echo "양호: FTP 접속 배너에 노출되는 정보가 없는 경우"
		echo "취약: FTP 접속 배너에 노출되는 정보가 있는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ FTP 서비스 정보 노출 점검 ]"

		PROCESS_CHECKER vsftpd
		VSFTPD=${PCK}
		PROCESS_CHECKER proftpd
		PROFTPD=${PCK}
		PROCESS_CHECKER pure-ftpd
		PUREFTPD=${PCK}

		if [ $VSFTPD -eq 0 ] && [ $PROFTPD -eq 0 ] && [ $PUREFTPD -eq 0 ]; then
			echo "[양호] FTP 서비스가 구동중이지 않음"
		else
			if [ $VSFTPD -eq 1 ]; then
				echo "[ vsFTPd 배너 설정 ]"
				for CONF in /etc/vsftpd/vsftpd.conf /etc/vsftpd.conf; do
					if [ -f "$CONF" ]; then
						BANNER=$(grep -i "^ftpd_banner" "$CONF" 2>/dev/null)
						if [ -n "$BANNER" ]; then
							echo "$BANNER"
							LB_CheckCase=1
						else
							echo "[확인] ftpd_banner 미설정 (기본 배너 사용)"
							LB_CheckCase=1
						fi
					fi
				done
			fi
			if [ $PROFTPD -eq 1 ]; then
				echo "[ ProFTPd 배너 설정 ]"
				for CONF in /etc/proftpd.conf /etc/proftpd/proftpd.conf /usr/local/etc/proftpd.conf; do
					if [ -f "$CONF" ]; then
						IDENT=$(grep -i "^ServerIdent" "$CONF" 2>/dev/null)
						if [ -n "$IDENT" ]; then
							echo "$IDENT"
							if echo "$IDENT" | grep -qi "off"; then
								echo "[양호] ServerIdent off 설정"
							else
								LB_CheckCase=1
							fi
						else
							echo "[확인] ServerIdent 미설정"
							LB_CheckCase=1
						fi
					fi
				done
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] FTP 서비스 정보가 노출됨"
			RESULT="BAD"
		elif [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] FTP 배너 설정 확인 필요"
			RESULT="CHECK"
		else
			echo "[양호] FTP 서비스 정보 노출 없음"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_346(){
	{
		echo "양호: 특정 IP주소 또는 호스트에서만 FTP 서버에 접속할 수 있도록 접근 제어 설정을 적용한 경우"
		echo "취약: FTP 서버에 접근 제어 설정을 적용하지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ FTP 서비스 접근 제어 점검 ]"

		PROCESS_CHECKER vsftpd
		VSFTPD=${PCK}
		PROCESS_CHECKER proftpd
		PROFTPD=${PCK}

		if [ $VSFTPD -eq 0 ] && [ $PROFTPD -eq 0 ]; then
			echo "[양호] FTP 서비스가 구동중이지 않음"
		else
			if [ $VSFTPD -eq 1 ]; then
				echo "[ vsFTPd 접근 제어 설정 ]"
				for CONF in /etc/vsftpd/vsftpd.conf /etc/vsftpd.conf; do
					if [ -f "$CONF" ]; then
						echo "** $CONF **"
						grep -i "userlist_enable\|userlist_deny\|userlist_file\|tcp_wrappers" "$CONF" 2>/dev/null
						LB_CheckCase=1
					fi
				done
			fi
			if [ $PROFTPD -eq 1 ]; then
				echo "[ ProFTPd 접근 제어 설정 ]"
				for CONF in /etc/proftpd.conf /etc/proftpd/proftpd.conf /usr/local/etc/proftpd.conf; do
					if [ -f "$CONF" ]; then
						echo "** $CONF **"
						grep -i "Limit\|Allow\|Deny\|Order" "$CONF" 2>/dev/null
						LB_CheckCase=1
					fi
				done
			fi

			echo ""
			echo "[ TCP Wrapper 설정 ]"
			if [ -f /etc/hosts.deny ]; then
				echo "** /etc/hosts.deny **"
				grep -v "^#" /etc/hosts.deny 2>/dev/null | grep -v "^$"
			fi
			if [ -f /etc/hosts.allow ]; then
				echo "** /etc/hosts.allow **"
				grep -v "^#" /etc/hosts.allow 2>/dev/null | grep -v "^$"
			fi
			LB_CheckCase=1
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] FTP 접근 제어 설정 확인 필요"
			RESULT="CHECK"
		else
			echo "[양호] FTP 서비스 미사용 또는 접근 제어 적용"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_347(){
	{
		echo "양호: SNMP 서비스를 v3 이상으로 사용하는 경우"
		echo "취약: SNMP 서비스를 v2 이하로 사용하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ SNMP 버전 점검 ]"

		PROCESS_CHECKER snmpd

		if [ ${PCK} -eq 1 ]; then
			SNMPD_CONF="/etc/snmp/snmpd.conf"
			if [ -f "$SNMPD_CONF" ]; then
				echo "[ $SNMPD_CONF ]"
				echo ""
				echo "** SNMPv1/v2c Community 설정 **"
				V2_COMM=$(grep -v "^#" "$SNMPD_CONF" 2>/dev/null | grep -i "rocommunity\|rwcommunity" | grep -v "rocommunity6\|rwcommunity6")
				if [ -n "$V2_COMM" ]; then
					echo "$V2_COMM"
					echo "[취약] SNMPv1/v2c community 설정이 존재"
					LB_BadCase=1
				else
					echo "[양호] SNMPv1/v2c community 미설정"
				fi
				echo ""
				echo "** SNMPv3 사용자 설정 **"
				V3_USER=$(grep -v "^#" "$SNMPD_CONF" 2>/dev/null | grep -i "createUser\|rouser\|rwuser\|usmUser")
				if [ -n "$V3_USER" ]; then
					echo "$V3_USER"
					echo "[양호] SNMPv3 사용자 설정 존재"
				else
					echo "[확인] SNMPv3 사용자 설정 없음"
					LB_CheckCase=1
				fi
			else
				echo "[확인] snmpd.conf 파일을 찾을 수 없음"
				LB_CheckCase=1
			fi
		else
			echo "[양호] SNMP 서비스가 구동중이지 않음"
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] SNMPv2 이하 사용"
			RESULT="BAD"
		elif [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] SNMP 버전 확인 필요"
			RESULT="CHECK"
		else
			echo "[양호] SNMPv3 이상 사용"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_348(){
	{
		echo "양호: SNMP 서비스에 접근 제어 설정이 되어 있는 경우"
		echo "취약: SNMP 서비스에 접근 제어 설정이 되어 있지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ SNMP Access Control 설정 점검 ]"

		PROCESS_CHECKER snmpd

		if [ ${PCK} -eq 1 ]; then
			SNMPD_CONF="/etc/snmp/snmpd.conf"
			if [ -f "$SNMPD_CONF" ]; then
				echo "[ $SNMPD_CONF ]"
				echo ""
				echo "** 접근 제어 설정 **"
				ACL_LINES=$(grep -v "^#" "$SNMPD_CONF" 2>/dev/null | grep -i "com2sec\|rocommunity\|rwcommunity\|rouser\|rwuser\|view\|access")
				if [ -n "$ACL_LINES" ]; then
					echo "$ACL_LINES"
					# rocommunity/rwcommunity에 IP 제한이 있는지 확인
					NO_IP_LIMIT=$(grep -v "^#" "$SNMPD_CONF" 2>/dev/null | grep -i "rocommunity\|rwcommunity" | grep -v "rocommunity6\|rwcommunity6" | awk '{if(NF<=2) print}')
					if [ -n "$NO_IP_LIMIT" ]; then
						echo ""
						echo "[취약] IP 제한 없는 community 설정 존재:"
						echo "$NO_IP_LIMIT"
						LB_BadCase=1
					else
						echo "[양호] 접근 제어 설정 적용됨"
					fi
				else
					echo "[확인] SNMP 접근 제어 설정을 확인할 수 없음"
					LB_CheckCase=1
				fi
			else
				echo "[확인] snmpd.conf 파일을 찾을 수 없음"
				LB_CheckCase=1
			fi
		else
			echo "[양호] SNMP 서비스가 구동중이지 않음"
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] SNMP 접근 제어 미설정"
			RESULT="BAD"
		elif [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] SNMP 접근 제어 설정 확인 필요"
			RESULT="CHECK"
		else
			echo "[양호] SNMP 접근 제어 설정됨"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_349(){
	{
		echo "양호: /etc/sudoers 파일 소유자가 root이고, 파일 권한이 640 이하인 경우"
		echo "취약: /etc/sudoers 파일 소유자가 root가 아니거나, 파일 권한이 640을 초과하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		echo "-------------------------------------------------------------------"
		echo "[ sudo 설정 파일 점검 ]"

		SUDOERS="/etc/sudoers"
		if [ -f "$SUDOERS" ]; then
			ls -l "$SUDOERS"
			echo ""
			OWNER=$(ls -l "$SUDOERS" | awk '{print $3}')
			PERM_STR=$(ls -l "$SUDOERS" | awk '{print $1}')

			if [ "$OWNER" != "root" ]; then
				echo "[취약] 소유자가 root가 아님: $OWNER"
				LB_BadCase=1
			else
				echo "[양호] 소유자: root"
			fi

			# 640 이하 확인: group write/execute 없음, other 모든 권한 없음
			GRP_W=$(echo "$PERM_STR" | cut -c6)
			GRP_X=$(echo "$PERM_STR" | cut -c7)
			OTH_R=$(echo "$PERM_STR" | cut -c8)
			OTH_W=$(echo "$PERM_STR" | cut -c9)
			OTH_X=$(echo "$PERM_STR" | cut -c10)
			if [ "$GRP_W" != "-" ] || [ "$GRP_X" != "-" ] || [ "$OTH_R" != "-" ] || [ "$OTH_W" != "-" ] || [ "$OTH_X" != "-" ]; then
				echo "[취약] 권한이 640 초과: $PERM_STR"
				LB_BadCase=1
			else
				echo "[양호] 권한: $PERM_STR"
			fi
		else
			echo "[양호] /etc/sudoers 파일이 존재하지 않음"
		fi

		# sudoers.d 디렉터리 점검
		if [ -d /etc/sudoers.d ]; then
			echo ""
			echo "[ /etc/sudoers.d 디렉터리 점검 ]"
			BAD_SUDO=$(find /etc/sudoers.d -type f \( ! -user root -o -perm -041 \) 2>/dev/null)
			if [ -n "$BAD_SUDO" ]; then
				echo "[취약] 권한 설정 미흡 파일:"
				echo "$BAD_SUDO" | while read f; do ls -l "$f" 2>/dev/null; done
				LB_BadCase=1
			else
				ls -la /etc/sudoers.d/
				echo "[양호] sudoers.d 파일 권한 적절"
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] sudo 설정 파일 권한 미흡"
			RESULT="BAD"
		else
			echo "[양호] sudo 설정 파일 권한 적절"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_350(){
	{
		echo "양호: NTP 및 시각 동기화 설정이 기준에 따라 적용된 경우"
		echo "취약: NTP 및 시각 동기화 설정이 기준에 따라 적용되어 있지 않은 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_GoodCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ NTP 및 시각 동기화 설정 점검 ]"

		# ntpd 확인
		PROCESS_CHECKER ntpd
		NTPD=${PCK}

		# chronyd 확인
		PROCESS_CHECKER chronyd
		CHRONYD=${PCK}

		if [ $NTPD -eq 1 ]; then
			echo "[NTP 서비스 구동 중]"
			echo ""
			if [ -f /etc/ntp.conf ]; then
				echo "[ /etc/ntp.conf ]"
				grep -v "^#" /etc/ntp.conf 2>/dev/null | grep -v "^$"
				echo ""
				NTP_SERVER=$(grep -v "^#" /etc/ntp.conf 2>/dev/null | grep "^server")
				if [ -n "$NTP_SERVER" ]; then
					echo "[양호] NTP 서버 설정 존재"
					LB_GoodCase=1
				else
					echo "[취약] NTP 서버 미설정"
					LB_BadCase=1
				fi
			fi
			echo ""
			echo "[ ntpq -pn ]"
			ntpq -pn 2>/dev/null
		elif [ $CHRONYD -eq 1 ]; then
			echo "[Chrony 서비스 구동 중]"
			echo ""
			if [ -f /etc/chrony.conf ]; then
				echo "[ /etc/chrony.conf ]"
				grep -v "^#" /etc/chrony.conf 2>/dev/null | grep -v "^$"
				echo ""
				CHRONY_SERVER=$(grep -v "^#" /etc/chrony.conf 2>/dev/null | grep -E "^server|^pool")
				if [ -n "$CHRONY_SERVER" ]; then
					echo "[양호] Chrony 서버 설정 존재"
					LB_GoodCase=1
				else
					echo "[취약] Chrony 서버 미설정"
					LB_BadCase=1
				fi
			fi
			echo ""
			echo "[ chronyc sources ]"
			chronyc sources 2>/dev/null
		else
			echo "[취약] NTP/Chrony 서비스가 구동중이지 않음"
			LB_BadCase=1
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] NTP 및 시각 동기화 미설정"
			RESULT="BAD"
		elif [ $LB_GoodCase -eq 1 ]; then
			echo "[양호] NTP 및 시각 동기화 설정 적절"
			RESULT="GOOD"
		else
			echo "[확인] NTP 설정 확인 필요"
			RESULT="CHECK"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}

Unix_351(){
	{
		echo "양호: 디렉터리 내 로그 파일의 소유자가 root이고, 권한이 644 이하인 경우"
		echo "취약: 디렉터리 내 로그 파일의 소유자가 root가 아니거나, 권한이 644를 초과하는 경우"
	} > $STANDARD_FILE
	{
		LB_BadCase=0
		LB_CheckCase=0
		echo "-------------------------------------------------------------------"
		echo "[ 로그 디렉터리 소유자 및 권한 점검 ]"

		LOG_DIR="/var/log"
		if [ -d "$LOG_DIR" ]; then
			echo "[ ${LOG_DIR} 내 주요 로그 파일 점검 ]"
			echo ""
			for LOGFILE in messages syslog secure auth.log cron maillog; do
				if [ -f "${LOG_DIR}/${LOGFILE}" ]; then
					ls -l "${LOG_DIR}/${LOGFILE}"
					OWNER=$(ls -l "${LOG_DIR}/${LOGFILE}" | awk '{print $3}')
					PERM_STR=$(ls -l "${LOG_DIR}/${LOGFILE}" | awk '{print $1}')
					if [ "$OWNER" != "root" ] && [ "$OWNER" != "syslog" ]; then
						echo "  -> [취약] 소유자: $OWNER (root 또는 syslog 아님)"
						LB_BadCase=1
					fi
					# 644 이하 확인: group write/execute 없음, other write/execute 없음
					GRP_P=$(echo "$PERM_STR" | cut -c6-7)
					OTH_P=$(echo "$PERM_STR" | cut -c9-10)
					if echo "$GRP_P" | grep -q '[wx]' || echo "$OTH_P" | grep -q '[wx]'; then
						echo "  -> [취약] 권한: $PERM_STR (644 초과)"
						LB_BadCase=1
					fi
				fi
			done

			echo ""
			echo "[ 기타 로그 파일 (권한 644 초과) ]"
			BAD_LOGS=$(find "$LOG_DIR" -maxdepth 1 -type f -perm /133 2>/dev/null | head -20)
			if [ -n "$BAD_LOGS" ]; then
				echo "$BAD_LOGS" | while read f; do ls -l "$f" 2>/dev/null; done
				LB_CheckCase=1
			else
				echo "[양호] 644 초과 파일 없음"
			fi
		fi

		echo "-------------------------------------------------------------------"
		if [ $LB_BadCase -eq 1 ]; then
			echo "[취약] 로그 파일 소유자 또는 권한 미흡"
			RESULT="BAD"
		elif [ $LB_CheckCase -eq 1 ]; then
			echo "[확인] 로그 파일 권한 확인 필요"
			RESULT="CHECK"
		else
			echo "[양호] 로그 디렉터리 소유자 및 권한 적절"
			RESULT="GOOD"
		fi
		echo "-------------------------------------------------------------------"
	} > $STATUS_FILE
}


SH_HEADER
XML_HEADER

echo ""
echo "-------------------------------------------------------------------"
echo " > RAW_DATA EXTRACT START..."
RAW_PRINT
echo " > RAW_DATA EXTRACT COMPLETE..."
echo "-------------------------------------------------------------------"
echo " > SECURITY CHECK START..."
echo ""
CHECK "Unix_026" "U_01" "계정관리" "U-01. root 계정 원격 접속 제한" "HIGH" 2> /dev/null
CHECK "Unix_069" "U_02" "계정관리" "U-02. 비밀번호 관리정책 설정" "HIGH" 2> /dev/null
CHECK "Unix_302" "U_03" "계정관리" "U-03. 계정 잠금 임계값 설정" "HIGH" 2> /dev/null
CHECK "Unix_070" "U_04" "계정관리" "U-04. 비밀번호 파일 보호" "HIGH" 2> /dev/null
CHECK "Unix_331" "U_05" "계정관리" "U-05. root 이외의 UID가 '0' 금지" "HIGH" 2> /dev/null
CHECK "Unix_339" "U_06" "계정관리" "U-06. 사용자 계정 su 기능 제한" "HIGH" 2> /dev/null
CHECK "Unix_316" "U_07" "계정관리" "U-07. 불필요한 계정 제거" "LOW" 2> /dev/null
CHECK "Unix_073" "U_08" "계정관리" "U-08. 관리자 그룹에 최소한의 계정 포함" "MEDIUM" 2> /dev/null
CHECK "Unix_330" "U_09" "계정관리" "U-09. 계정이 존재하지 않는 GID 금지" "LOW" 2> /dev/null
CHECK "Unix_142" "U_10" "계정관리" "U-10. 동일한 UID 금지" "MEDIUM" 2> /dev/null
CHECK "Unix_165" "U_11" "계정관리" "U-11. 사용자 Shell 점검" "LOW" 2> /dev/null
CHECK "Unix_327" "U_12" "계정관리" "U-12. 세션 종료 시간 설정" "LOW" 2> /dev/null
CHECK "Unix_341" "U_13" "계정관리" "U-13. 안전한 비밀번호 암호화 알고리즘 사용" "MEDIUM" 2> /dev/null
CHECK "Unix_121" "U_14" "파일 및 디렉토리 관리" "U-14. root 홈, 패스 디렉터리 권한 및 패스 설정" "HIGH" 2> /dev/null
CHECK "Unix_095" "U_15" "파일 및 디렉토리 관리" "U-15. 파일 및 디렉터리 소유자 설정" "HIGH" 2> /dev/null
CHECK "Unix_326" "U_16" "파일 및 디렉토리 관리" "U-16. /etc/passwd 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_342" "U_17" "파일 및 디렉토리 관리" "U-17. 시스템 시작 스크립트 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_304" "U_18" "파일 및 디렉토리 관리" "U-18. /etc/shadow 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_305" "U_19" "파일 및 디렉토리 관리" "U-19. /etc/hosts 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_323" "U_20" "파일 및 디렉토리 관리" "U-20. /etc/(x)inetd.conf 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_324" "U_21" "파일 및 디렉토리 관리" "U-21. /etc/(r)syslog.conf 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_306" "U_22" "파일 및 디렉토리 관리" "U-22. /etc/services 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_091" "U_23" "파일 및 디렉토리 관리" "U-23. SUID, SGID, Sticky bit 설정 파일 점검" "HIGH" 2> /dev/null
CHECK "Unix_307" "U_24" "파일 및 디렉토리 관리" "U-24. 사용자, 시스템 환경변수 파일 소유자 및 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_093" "U_25" "파일 및 디렉토리 관리" "U-25. world writable 파일 점검" "HIGH" 2> /dev/null
CHECK "Unix_144" "U_26" "파일 및 디렉토리 관리" "U-26. /dev에 존재하지 않는 device 파일 점검" "HIGH" 2> /dev/null
CHECK "Unix_309" "U_27" "파일 및 디렉토리 관리" "U-27. $HOME/.rhosts, hosts.equiv 사용 금지" "HIGH" 2> /dev/null
CHECK "Unix_027" "U_28" "파일 및 디렉토리 관리" "U-28. 접속 IP 및 포트 제한" "HIGH" 2> /dev/null
CHECK "Unix_317" "U_29" "파일 및 디렉토리 관리" "U-29. hosts.lpd 파일 소유자 및 권한 설정" "LOW" 2> /dev/null
CHECK "Unix_122" "U_30" "파일 및 디렉토리 관리" "U-30. UMASK 설정 관리" "MEDIUM" 2> /dev/null
CHECK "Unix_319" "U_31" "파일 및 디렉토리 관리" "U-31. 홈 디렉토리 소유자 및 권한 설정" "MEDIUM" 2> /dev/null
CHECK "Unix_318" "U_32" "파일 및 디렉토리 관리" "U-32. 홈 디렉토리로 지정한 디렉토리의 존재 관리" "MEDIUM" 2> /dev/null
CHECK "Unix_166" "U_33" "파일 및 디렉토리 관리" "U-33. 숨겨진 파일 및 디렉토리 검색 및 제거" "LOW" 2> /dev/null
CHECK "Unix_332" "U_34" "서비스 관리" "U-34. Finger 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_013" "U_35" "서비스 관리" "U-35. 공유 서비스에 대한 익명 접근 제한 설정" "HIGH" 2> /dev/null
CHECK "Unix_310" "U_36" "서비스 관리" "U-36. r 계열 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_333" "U_37" "서비스 관리" "U-37. crontab 설정파일 권한 설정" "HIGH" 2> /dev/null
CHECK "Unix_334" "U_38" "서비스 관리" "U-38. DoS 공격에 취약한 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_015" "U_39" "서비스 관리" "U-39. 불필요한 NFS 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_014" "U_40" "서비스 관리" "U-40. NFS 접근 통제" "HIGH" 2> /dev/null
CHECK "Unix_335" "U_41" "서비스 관리" "U-41. 불필요한 automountd 제거" "HIGH" 2> /dev/null
CHECK "Unix_016" "U_42" "서비스 관리" "U-42. 불필요한 RPC 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_312" "U_43" "서비스 관리" "U-43. NIS, NIS+ 점검" "HIGH" 2> /dev/null
CHECK "Unix_336" "U_44" "서비스 관리" "U-44. tftp, talk 서비스 비활성화" "HIGH" 2> /dev/null
CHECK "Unix_007" "U_45" "서비스 관리" "U-45. 메일 서비스 버전 점검" "HIGH" 2> /dev/null
CHECK "Unix_010" "U_46" "서비스 관리" "U-46. 일반 사용자의 메일 서비스 실행 방지" "HIGH" 2> /dev/null
CHECK "Unix_009" "U_47" "서비스 관리" "U-47. 스팸 메일 릴레이 제한" "HIGH" 2> /dev/null
CHECK "Unix_005" "U_48" "서비스 관리" "U-48. expn, vrfy 명령어 제한" "MEDIUM" 2> /dev/null
CHECK "Unix_325" "U_49" "서비스 관리" "U-49. DNS 보안 버전 패치" "HIGH" 2> /dev/null
CHECK "Unix_066" "U_50" "서비스 관리" "U-50. DNS Zone Transfer 설정" "HIGH" 2> /dev/null
CHECK "Unix_343" "U_51" "서비스 관리" "U-51. DNS 서비스의 취약한 동적 업데이트 설정 금지" "MEDIUM" 2> /dev/null
CHECK "Unix_344" "U_52" "서비스 관리" "U-52. Telnet 서비스 비활성화" "MEDIUM" 2> /dev/null
CHECK "Unix_345" "U_53" "서비스 관리" "U-53. FTP 서비스 정보 노출 제한" "LOW" 2> /dev/null
CHECK "Unix_037" "U_54" "서비스 관리" "U-54. 암호화되지 않는 FTP 서비스 비활성화" "MEDIUM" 2> /dev/null
CHECK "Unix_337" "U_55" "서비스 관리" "U-55. FTP 계정 Shell 제한" "MEDIUM" 2> /dev/null
CHECK "Unix_346" "U_56" "서비스 관리" "U-56. FTP 서비스 접근 제어 설정" "LOW" 2> /dev/null
CHECK "Unix_011" "U_57" "서비스 관리" "U-57. Ftpusers 파일 설정" "MEDIUM" 2> /dev/null
CHECK "Unix_147" "U_58" "서비스 관리" "U-58. 불필요한 SNMP 서비스 구동 점검" "MEDIUM" 2> /dev/null
CHECK "Unix_347" "U_59" "서비스 관리" "U-59. 안전한 SNMP 버전 사용" "HIGH" 2> /dev/null
CHECK "Unix_340" "U_60" "서비스 관리" "U-60. SNMP Community String 복잡성 설정" "MEDIUM" 2> /dev/null
CHECK "Unix_348" "U_61" "서비스 관리" "U-61. SNMP Access Control 설정" "HIGH" 2> /dev/null
CHECK "Unix_321" "U_62" "서비스 관리" "U-62. 로그인 시 경고 메시지 설정" "LOW" 2> /dev/null
CHECK "Unix_349" "U_63" "서비스 관리" "U-63. sudo 명령어 접근 관리" "MEDIUM" 2> /dev/null
CHECK "Unix_118" "U_64" "패치 관리" "U-64. 주기적 보안 패치 및 벤더 권고사항 적용" "HIGH" 2> /dev/null
CHECK "Unix_350" "U_65" "로그 관리" "U-65. NTP 및 시각 동기화 설정" "MEDIUM" 2> /dev/null
CHECK "Unix_329" "U_66" "로그 관리" "U-66. 정책에 따른 시스템 로깅 설정" "MEDIUM" 2> /dev/null
CHECK "Unix_351" "U_67" "로그 관리" "U-67. 로그 디렉터리 소유자 및 권한 설정" "MEDIUM" 2> /dev/null
echo ""
echo " > SECURITY CHECK COMPLETE..."
echo "-------------------------------------------------------------------"

XML_FOOTER

rm -rf ksecure
