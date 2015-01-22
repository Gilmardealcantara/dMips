#!/bin/bash

load_variables(){
		memory=./unidadesLogicas/memory.txt
		register=./unidadesLogicas/register.txt 
		saida=./saida.txt
		saidaSinais=./saida_sinais.txt
		dec=./unidadesLogicas/arquivo_de_decodificacao #para decodificar instruções
		
		#nesessario iniciar se nao nao conta como parametro
		register1=x 
		register2=x 
		register3=x
		Write_Data=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
		Read_data1=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
		Read_data2=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
		Read_data=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx		
}

#------------------------------------------------------------------------------------------------------------    
#reconhece e seta os sinais de controle
controle(){ 
    Branch=0                        #sempre igual a zero pois nao temos intruçoes de salto 
	if [ "$tipo" == "w" ]; then
	    RedDst=1;                   #escreve no 20-16, 15... e imdiado endereço....sla, 2 registradores somente 
	    AluOp='00'
	    AluOperation='010';         #sempre soma para obter o proximo endereço
	    AluSrc=1;                   # pega 15... para a lu e nao read data2
        if [ "$instrucao" == "lw" ]; then
            RegWrite=1;             #escreve no banco de regs	    
	        MemRead=1; 	            #le da memoria    
	        MemWrite=0;
	        MemtoReg=1              #quer leitura da memoria
	        TempoInstr=1100         #tempo da istruçao lw, em biniario por causa da conversao, padrao binario (12)
	    else
            RegWrite=0
	        MemRead=0; 
	        MemWrite=1;             # escreve na memoria
   	        MemtoReg=0              #independente
	        TempoInstr=1011         #tempo da istruçao sw, em biniario por causa da conversao, padrao binario (11)
	    fi
		
	else                            #tipo R
        RedDst=0;                   # escreve no 15-11 as operaçao de 25-21 com 20-16	    
        MemRead=0;                  # opera so em registraores
        MemWrite=0;                 # opera so em registradores
        MemtoReg=0;                 #quer o resultado da alu
        AluSrc=0;                   #pega read dat 2 para a alu
        RegWrite=1;                 #sempre escreve no banco de regs 
        AluOp='10'
                                    #define a operaçao da alu        
        case "${instrucao}" in
            "add") AluOperation='010' ;;
            "sub") AluOperation='110' ;;
            "and") AluOperation='000' ;;
            "or") AluOperation='001' ;;
            "slt") AluOperation='111' ;;  
        esac
	    TempoInstr=1000           #tempo das istruçoes do tipo R,em biniario por causa da conversao, padrao binario (8) 
	fi
	TempoTotal=$(($TempoTotal+$TempoInstr))
	TempoTotal_b=`echo "obase=2; ibase=10; $TempoTotal" | bc` #nesessario se nao fica convertido para as outras intruçoes

}
#------------------------------------------------------------------------------------------------------------    
#recebe o numero de casas $2 e o numero a ser complementado $1
completaNum(){
NumEntrada=`echo $1 | cut -d'-' -f2` #se for negativo tita o sinal de menos 
numAlgarismos=${#NumEntrada}        #pega o numero de caracteres
dim=$2                              #recebe a dimençao que se deseja que o nuero fique

for((i=0 ; i< dim-numAlgarismos ; i++))
do                                  #faz (dim-numero de caracteres) de zeros 
    var=${var}0
done 

numNovo=${var}$NumEntrada           #concatena
echo $numNovo                       #escreve para cer usado como retorno
}

#------------------------------------------------------------------------------------------------------------    

decodificacao(){
#pega numeros, dodifica o assemby 
#pega o primero reg do tipo r e do tipo i
    reg1=`echo $line | cut -d ' ' -f2 | cut -d ',' -f1`     #reg com pelto $s1
    numreg1=`echo $reg1 | cut -b 3`                         #numero 0 a 7  
    tiporeg1=`echo $reg1 | cut -b 2`                        #letra s ou t

    #para o regitrador 1
    if [ $tiporeg1 == 't' ]; then
        register1=$(($numreg1+8))
    else
        register1=$(($numreg1+16))
    fi

    #Instruçoes do tipo I (lw e sw) 
    if [ $tipo == 'w' ]; then 
        #le segundo reg do tipo i
        reg2=`echo $line | cut -d ' ' -f2 | cut -d',' -f2 `
        numreg2=`echo $reg2 | cut -d'(' -f2 | cut -b 3`
        tiporeg2=`echo $reg2 | cut -d'(' -f2 | cut -b 2`
        
        #para o regitrador 2
        if [ $tiporeg2 == 't' ]; then
            register2=$(($numreg2+8))
        else
            register2=$(($numreg2+16))
        fi

        #immediato 
        imediato=`echo $reg2 | cut -d'(' -f1`

        #-------> Decodifica instruçao do tipo I o Assebly para binario
        #a variavel instruçao tem o opcode
        instrucao_b=`grep ^$instrucao $dec  | cut -d' ' -f3` #decodifica opcode
        register1_b=`echo "obase=2; ibase=10; $register1" | bc` #decodifica reg1
        register2_b=`echo "obase=2; ibase=10; $register2" | bc` #decodifica reg2
        imediato_b=`echo "obase=2; ibase=10; $imediato" | bc` #decodifica imediato
        
        register1_b=`completaNum $register1_b 5` #completa a quantidade de casas para 5
        register2_b=`completaNum $register2_b 5` #completa a quantidade de casas para 5
        imediato_b=`completaNum $imediato_b 16` #completa a quantidade de casas para 5         
        #o reg 2 que sera escrito
        #instruçao decodificada em binario
        instrucao_Dec=`echo "$instrucao_b$register2_b$register1_b$imediato_b"`
    
        
        #----------------->VARIAVEIS DE SAIDA
        I_25_21=$register2_b # reg a ser lido 
        I_20_16=$register1_b #reg que vai ser escrito
        # reg desnessessario reg3 5 primeiros caraqteres de imediato  
        I_15_11=""
        for((i=1; i<=5; i++))
        do  
            I_15_11=${I_15_11}`echo $imediato_b | cut -b $i`        
        done
        I_15_0=$imediato_b
    
    else #Instruçoes do tipo R
        #segundo do tipo r
        reg2=`echo $line | cut -d ' ' -f2 | cut -d ',' -f2`
        numreg2=`echo $reg2 | cut -b 3`
        tiporeg2=`echo $reg2 | cut -b 2`
        #para o regitrador 2
        
        if [ $tiporeg2 == 't' ]; then
            register2=$(($numreg2+8))
        else
            register2=$(($numreg2+16))
        fi
        
        #terceiro do tipo r
        reg3=`echo $line | cut -d ' ' -f2 | cut -d ',' -f3`
        numreg3=`echo $reg3 | cut -b 3`
        tiporeg3=`echo $reg3 | cut -b 2`
        #para o regitrador 1
        if [ $tiporeg3 == 't' ]; then
            register3=$(($numreg3+8))
        else
            register3=$(($numreg3+16))
        fi
        #------->Decodifica instruçao do tipo R o Assebly para binario
        #a variavel instruçao tem o opcode
        
        #echo $line
        #echo $instrucao $register1 $register2 $register3
        instrucao_b=`grep ^$instrucao $dec  | cut -d' ' -f3` #decodifica opcode
        register1_b=`echo "obase=2; ibase=10; $register1" | bc` #decodifica reg1
        register2_b=`echo "obase=2; ibase=10; $register2" | bc` #decodifica reg2
        register3_b=`echo "obase=2; ibase=10; $register3" | bc` #decodifica reg3
        Function=`grep ^$instrucao $dec  | cut -d' ' -f5`
        
        register1_b=`completaNum $register1_b 5` #completa a quantidade de casas para 5
        register2_b=`completaNum $register2_b 5` #completa a quantidade de casas para 5
        register3_b=`completaNum $register3_b 5` #completa a quantidade de casas para 5         
        #o reg 3 que sera escrito
        #Instruçao decodificada em binario
        instrucao_Dec=`echo "$instrucao_b$register3_b$register2_b${register1_b}00000$Function"`
        
        #-------------------------->VARIAVEIS DE SAIDA
        I_25_21=$register2_b # reg a ser lido     
        I_20_16=$register3_b #reg q vai ser lido   
        I_15_11=$register1_b # reg que vai ser escrito
        I_15_0=`echo 00000$Function`        
        
    fi
    #VARIAVEIS DE SAIDA
    #recorta a intruçao para imprimir 
    I_31_0=$instrucao_Dec
    I_31_26=$instrucao_b    

}

#------------------------------------------------------------------------------------------------------------    

#recebe dois parametros
memory_data(){ #1=endereoço lido e/ou escrito //2 numero a ser escrito
	#lEITURA
	if [ $MemRead -eq 1 ]; then	
	    Read_data=`cat -v $memory | grep ^$1 | cut -d' ' -f2 | cut -d'^' -f1`	
	fi
    #ESCRITA
	if [ $MemWrite -eq 1 ]; then 	    
        wd=`completaNum $2 32` #completa numero de algarismos antes de gravar o arquivo
		item=`grep ^$1 $memory` # endereço com memoria
		sed "s/$item/$1 $wd/" $memory > $memory.tmp	
	    mv $memory.tmp $memory
	fi
}

#------------------------------------------------------------------------------------------------------------    

#recebe 3 indereços, 1 dado e retorna 2 dados 1 e 2 leitura, 3 escrita. 4 dado
register_bank(){
    #lEITURA sempre vai ler
	Read_data1=`cat -v $register | grep ^$1 | cut -d' ' -f2 | cut -d'^' -f1`
	Read_data2=`cat -v $register | grep ^$2 | cut -d' ' -f2 | cut -d'^' -f1`
	#nescessario para o sw escrever o varlor de Reg1 na memoria $3=Reg1
	Read_data3=`cat -v $register | grep ^$3 | cut -d' ' -f2 | cut -d'^' -f1`
	
	#ESCRITA
	if [ $RegWrite -eq 1 ]; then 
		wd=`completaNum $4 32` #completa numero de algarismos antes de gravar o arquivo		
		Write_register=`grep ^$3 $register`
		sed "s/$Write_register/$3 $wd/" $register > $register.tmp
		mv $register.tmp $register
	fi	
}

#------------------------------------------------------------------------------------------------------------    
complento2(){
#recebe o numero a ser complemntado
#descobre quantos algarismos tem o numero
NumEntrada=$1
numAlgarismos=${#NumEntrada}

cmp2=""
#nao pega o primeiro caracter porq ele e o sinal
#inverte o numero
#tira o traço proq e negativo(i=3)
#tirar->arley por algam motivo sombrio do destino e 3 e nao 2, 3 um algarismo a mais
for((i=3; i<=numAlgarismos; i++)) 
do 
    var=`echo $1 | cut -b $i`
    if [ $var -eq 0 ]; then
        var=1
    else
        var=0
    fi
    cmp2="$cmp2${var}"   
done     
#soma 1 mas faz em decimal, volta para binario e temos o complento de 2   
cmp2=`echo "obase=10; ibase=2; $cmp2" | bc `
cmp2=$(($cmp2+1)) 
cmp2=`echo "obase=2; ibase=10; $cmp2" | bc `
    echo $cmp2 #retorno    
}

#---------------------------------------------------------------------   
#recebe 2 parametros e depende dos sinais de AluCtrl
#AluOperation tres bits 
# para soma e subitraçao convete para decimal e depois opera e descoverte o resultado
#retorno em binario
alu(){ #recebe dois parametros em binario
    result=""
	#soma
	if [ $AluOperation == '010' ]; then
	    var1=`echo "obase=10; ibase=2; $1" | bc`
	    var2=`echo "obase=10; ibase=2; $2" | bc`	    
		r=$(($var1+$var2))	    	
		result=`echo "obase=2; ibase=10; $r" | bc`
	fi	
	#subitrai
	if [ $AluOperation == '110' ] || [ $AluOperation == '111' ]; then # instruçoes sub ou slt
	    var1=`echo "obase=10; ibase=2; $1" | bc`
	    var2=`echo "obase=10; ibase=2; $2" | bc`	    
		r=$(($var1-$var2))		
		result=`echo "obase=2; ibase=10; $r" | bc`		
	fi
    #and faz bit a bit
	if [ $AluOperation == '000' ]; then
			
		for((i=1; i<=32; i++))
	    do 
            var1=`echo $1 | cut -b $i`;
            var2=`echo $2 | cut -b $i`;                			
		    and=$(($var1&$var2))
		    
		    result=${result}$and	
        done
    fi
    #or faz bit a bit
	if [ $AluOperation == '001' ]; then
			
		for((i=1; i<=32; i++))
	    do 
            var1=`echo $1 | cut -b $i`;
            var2=`echo $2 | cut -b $i`;                			
		    or=$(($var1|$var2))
		    
		    result=${result}$or	
        done
    fi
    #sera o valor de zero
    zero=0
	if [ $result -eq 0 ]; then
	    zero=1
	fi
	
}
#Escreve as instruçoes em binario na memoria
#recebe PC e instrução decodificada 
EscrInstMem(){
    #calcula a posiça da memoria 
    EndEscrita=$(($1+65536)) #endereço e memoria valido

    if [ $EndEscrita -ge 66037 ]; then #pc max=500
        echo -e "\t\033[02;31m\nERRO!!!\nPosiçao de memoria invalida\nposicacao=$EndEscrita\nreveja o a posiçao inicial do seu pc que deve ser menor que (501-numero de instruções)\nTambem e viavel checar seu arquivo de memoria"; tput sgr0     
        cp ${register}.bkp ${register}
        cp ${memory}.bkp ${memory}    
        exit 1 
    fi

    EndEscrita=`echo "obase=16; ibase=10; $EndEscrita" | bc`    #passar para base 16   
    item=`grep ^$EndEscrita $memory`                            # endereço com memoria a serem modificados 
	sed "s/$item/$EndEscrita $2/" $memory > $memory.tmp	        #modifica a memoria e mantem o endereço
    mv $memory.tmp $memory
	
}

##-------------------------------------------MAIN-----------------------------------------------------------------    

barramento(){
    tipo=`echo $line | cut -d'#' -f1 | cut -d' ' -f1 | cut -b 2`
    instrucao=`echo $line | cut -d'#' -f1 | cut -d' ' -f1` #pega o pcode
    load_variables                  #carrega algumas variaveis uteis    
    controle                        #seta valores nas variaveis de controle                                
    decodificacao                   #obtem valores de $reg1 $reg2 $reg3\n$register1 $register2 $register3 $imediato 
    EscrInstMem $PC $instrucao_Dec  #manda intruçao decodificada para a memoria
                                    #echo -e "\nnumreg1= $numreg1 numreg2= $numreg2 $reg1 $reg2 $reg3\n-$register1 -$register2 ->$register3 -$imediato\n"

                    # rd1      rd2        rd3(sw)              
    register_bank $register2 $register3 $register1 $Write_Data  #valore a ser escrito
 
                                    #rd1 e o conteudo do reg2
    if [ $tipo == 'w' ]; then       #tipo i #read data2 e desnessesario
                                    #Ime=`echo "obase=2; ibase=10; $imediato" | bc` #coverter imdiato para binario
        alu $Read_data1 $imediato_b #endereço e result que tem q ir para a base 16
        AluResult=$result           #salva o resultado original da alu
        result=`echo "obase=10; ibase=2; $result" | bc` #resultado da alu e em binario, converte para decimal
        result=$(($result+65536))                       #calcula o endereço de memoria baseado no primeiro enderço dessa	em decimal	
                                                        #erro cso estore a memoria
        if [ $result -ge 66037 ]; then
            echo -e "\n\t\033[02;31mERRO!!!\nPosiçao de memoria invalida\nposicacao=$result\nRefaca a sua instrucaçao $line\nTambem e viavel checar seu arquivo de memoria"; tput sgr0
            cp ${register}.bkp ${register}
            cp ${memory}.bkp ${memory}    
            exit 1 
        fi
             
        Address=`echo "obase=16; ibase=10; $result" | bc` #coverte resultado para base 16
        memory_data $Address $Read_data3                  # rd3 so pra p sw que escreve o conteudo do reguiste1
        Write_Data=$Read_data
        result=`echo "obase=2; ibase=10; $result" | bc`   #volta o valor para binario para a impreçao        
         

    else                            #tipo R                
        alu $Read_data1 $Read_data2
        AluResult=$result           #salva o resultado original da alu
                                            
        if [ "$instrucao" != "slt" ]; then      #trata o slt
                                                #coplemento de 2 caso o resultado seja negativo , ta em binario
            if [ $result -lt 0 ]; then          # pode ser sub entao faz complento e 2
                result=`completaNum $result 34` #motivo escroto do destino tem q ser 34
                result=`complento2 $result`
            fi    
            
            Write_Data=$result
        else                                                #se for slt tem q verificar e no pode fazer o complento2 
           if [ $result -lt 0 ]; then                       #menor q zero negativo  ou `echo $result | cut -b 1` == "-" 
                Write_Data=0000000000000000000000000000001
                result=`completaNum $result 34`             #motivo escroto do destino tem q ser 34
                result=`complento2 $result`                 #complenta a saoda da alu para a tela  
                
           else
                Write_Data=0000000000000000000000000000000
           fi    
        fi
                
    fi

                                                                #chama de novo pois ja tem o valor de write data    
    register_bank $register2 $register3 $register1 $Write_Data  #valore a ser escrito
    #outra vex por re o register com nada escrito se estiver tranbalhand com mesms resgs ler depois da escrita
    register_bank $register2 $register3 $register1 $Write_Data  #valore a ser escrito     
            
    PC=$(($PC+1)) 
    PC_b=`echo "obase=2; ibase=10; $PC" | bc`    #converte para binario
    #echo -e "reg3==$reg1 reg3==$reg2 reg3=$reg3 imediato=$imediato\naluresult=$result \naddress=$Address wd=$Write_Data \nrd1=$Read_data1 \nrd2=$Read_data2 \nrd=$Read_data"    

}
#covertea a entrada para o padrao passado como parametro #deful e binario
#parametro $1 = {d=decimal b=binario h=hexadecimal} ; $2 numero a ser convertido
converte(){
    #padrao binario
    if [ "$2" != "" ] && [ `echo $2 | cut -b 1` != x ]; then #se nao estivar vazia e nao ser composta cd 'x'
        if [ $1 == d ]; then 
            echo "obase=10; ibase=2; $2" | bc    
            return
        fi    
        if [ $1 == h ]; then
            echo "obase=16; ibase=2; $2" | bc
            return
        fi
    fi
    var=$2 #se estivar vazia completa com x 
    if [ -z $var ]; then
    	var=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    	echo $var
    	return
    fi

    echo $2             #para ter um retorno
    
}
#e feita en conjunto com a funçao de converçao
# parametro $1 = d =decimal b=binario h=hexadecimal 
imprime(){

    echo -e "\n\t\033[01;30m Instrucão\t`echo $line | cut -d'#' -f1 `"; tput sgr0
	echo -e "\t\t\t\033[01;30m -----------------####Saida###---------------"; tput sgr0
    
    echo -e "\t\033[01;30m PC\t\t`converte $1 $PC_b`"; tput sgr0
    
    echo -e "\t\033[02;34m I[31-0]\t`converte $1 $I_31_0`"; tput sgr0
    echo -e "\t\033[02;34m I[31-26]\t`converte $1 $I_31_26`"; tput sgr0
    echo -e "\t\033[02;34m I[25-21]\t`converte $1 $I_25_21`"; tput sgr0
    echo -e "\t\033[02;34m I[20-16]\t`converte $1 $I_20_16`"; tput sgr0
    echo -e "\t\033[02;34m I[15-11]\t`converte $1 $I_15_11`"; tput sgr0
    echo -e "\t\033[02;34m I[15-0]\t`converte $1 $I_15_0`"; tput sgr0
    #sinais nao sao convertidos
    echo -e "\t\033[02;32m RedDst\t\t$RedDst"; tput sgr0
    echo -e "\t\033[02;32m Branch\t\t$Branch"; tput sgr0
    echo -e "\t\033[02;32m MemRead\t$MemRead"; tput sgr0
	echo -e "\t\033[02;32m MemWrite\t$MemWrite"; tput sgr0
	echo -e "\t\033[02;32m MemtoReg\t$MemtoReg"; tput sgr0
	echo -e "\t\033[02;32m AluOp\t\t`converte $1 $AluOp`"; tput sgr0
	echo -e "\t\033[02;32m AluOperation\t`converte $1 $AluOperation`"; tput sgr0
	echo -e "\t\033[02;32m AluSrc\t\t$AluSrc"; tput sgr0
	echo -e "\t\033[02;32m RegWrite\t$RegWrite"; tput sgr0
	
	echo -e "\t\033[02;34m Read_data1\t`converte $1 $Read_data1`"; tput sgr0
	echo -e "\t\033[02;34m Read_data2\t`converte $1 $Read_data2`"; tput sgr0
	echo -e "\t\033[02;34m Read_data\t`converte $1 $Read_data`"; tput sgr0
    Write_Data32=`completaNum $Write_Data 32`
    AluResult32=`completaNum $AluResult 32`
    imediato_b32=`completaNum $imediato_b 32`
    imediato_bAj32=`completaNum $imediato_b 30`
	echo -e "\t\033[02;34m Write_Data\t`converte $1 $Write_Data32`"; tput sgr0	
	echo -e "\t\033[02;34m AluResult\t`converte $1 $AluResult32`"; tput sgr0
	echo -e "\t\033[02;34m ImmEst\t\t`converte $1 $imediato_b32`"; tput sgr0
	echo -e "\t\033[02;34m ImmEstAj\t`converte $1 ${imediato_bAj32}00`"; tput sgr0
	echo -e "\t\033[02;34m Zero\t\t$zero"; tput sgr0
	echo -e "\t\033[02;34m QuantInstrt\t`converte $1 $PC_b`"; tput sgr0
	echo -e "\t\033[02;34m TempoInstr\t`converte $1 $TempoInstr` ns"; tput sgr0
    echo -e "\t\033[02;34m TempoTotal\t`converte $1 $TempoTotal_b` ns"; tput sgr0
	
	#cat $register 
}

#--------------------------------------
principal(){
    TempoTotal=0;                                   #inicia o contador de tempo antes de executar o codigo    
    echo "" > ./saida.txt                          # limpa o arquivo de saida
    read PC < $1                                #pc vai aumentar de 1 em 1 pois a memoria esta de 1 em 1 e com 34 bits ?    
    numLinhas=`wc -l $1 | cut -d' ' -f1`        # vai de 1 ate a quantidade de linhas do arquivo
    for((a=1; a <= $numLinhas; a++))            #variavel i o barramento modifica     
    do                                          #para poder ler linha por linha sem o uso do while voltar a linha origina, numera o arquivo
        
        clear                                   #limpa a tela 
        echo -e "\033[04;32;47m*******************************************PROSCESSADOR dMips******************************************************"; tput sgr0
        echo -e "\033[02;34;47m     Arley-Gilmar     "; tput sgr0
        
        line=`cat -vn $1 | grep  "     $a"`     # pega o numero de linhas, para usar o read e enter , com while nao da 
        line=${line:7}                          #pera o linha apartir do 7 caractere que é ' ' depois do numero que cat -n coloca
                    
        if [ "$line" != "$PC"  ]; then
            barramento
            imprime $3  >> ${saida}             #redireciona a impreçao para o arquivo desaida ./saida.txt         
            imprime $3                          #recebe o tipo de inmpressao mostra na tela
            if [ $2 == I ]; then                # se for o modo interativo pede o enter 
                if [ $a -ne $numLinhas ]; then
                    echo -e "\t\t\033[01;34m----------------------INSTRUCAÇÃO '$instrucao' FINALIZADA!!!--------------------------"; tput sgr0
                    echo -e "\033[01;34m---------------------APERTE <ENTER> PARA EXECUTAR A PROXIMA INTRUÇÃO--------------------------------------------"; tput sgr0
                    read                        #pede que digite algum caracter para continuar    
                else
                    echo -e "\t\t\033[01;34m----------------------CODICO EXECUTADO COM SUSCESSO!!! =D--------------------------- "; tput sgr0
                fi 
            fi
                                                         
        fi
    done
}

#começa aq - tela inicial #trata parametros
clear
echo -e "\033[04;32;47m*******************************************PROSCESSADOR dMips******************************************************"; tput sgr0
echo -e "\033[02;34;47m     Arley-Gilmar     "; tput sgr0

#verifica modo de execuçao
echo -e "\033[02;30;47m     Codigo a ser executado referente ao arquivo '$1'    "; tput sgr0
if [ $2 == D ]; then
    echo -e "\033[02;30;47m     As instuçoes serao executadas do modo Direto (Parametro '$2')    "; tput sgr0
elif [ $2 == I ]; then
    echo -e "\033[02;30;47m     As instuçoes serao executadas do modo Imterativo (Parametro '$2')    "; tput sgr0
else
    echo -e "\033[02;31;47m     Modo de execuçao Invalido!!! (tente 'D' ou 'I')    "; tput sgr0
    exit 2
fi

#verifica tipo de saida
if [ $3 == b ]; then
    echo -e "\033[02;30;47m     As saidas serao mostradas em binario (Parametro '$3')    "; tput sgr0
elif [ $3 == d ]; then
    echo -e "\033[02;30;47m     As saidas serao mostradas em decimal (Parametro '$3')    "; tput sgr0
elif [ $3 == h ]; then
    echo -e "\033[02;30;47m     As saidas serao mostradas em hexadecimal (Parametro '$3')    "; tput sgr0
else
    echo -e "\033[02;31;47m     Modo de visulizaçao Invalido!!! (tente 'b' 'h' ou 'd')    "; tput sgr0
    exit 2
fi


echo -e "\033[02;34;47m     Se Estiver Tudo OK Aperte <ENTER> e Boa Sorte    "; tput sgr0
read        

principal $1 $2 $3




######################################################################################################################bckp
##read line < $1 
#
#while read line 
#do
#    if [ "$line" != "$PC"  ]; then
         #echo $line
#        barramento
#        #testeimpresao $2
#        imprime $2
#        echo ---------------------------------------------------------------------------------
#        #sleep 1 
#    fi       
#done < $1


#ESTILOS
#00: Nenhum
#01: Negrito
#04: Sublinhado
#05: Piscante
#07: Reverso
#08: Oculto 

#CORES DE TEXTO
#30: Preto
#31: Vermelho
#32: Verde
#33: Amarelo
#34: Azul
#35: Magenta (Rosa)
#36: Ciano (Azul Ciano)
#37: Branco 

#CORES DE FUNDO
#40: Preto
#41: Vermelho
#42: Verde
#43: Amarelo
#44: Azul
#45: Magenta (Rosa)
#46: Ciano (Azul Ciano)
#47: Branco



#imprime(){
#
#    echo -e "Instrucão\t`echo $line | cut -d'#' -f1 `" 
#       echo -e "\nsaida------------------"
#    
#    echo -e "PC\t\t`converte $1 $PC_b`"
#    
#    echo -e "I[31-0]\t\t`converte $1 $I_31_0`"
#    echo -e "I[31-26]\t`converte $1 $I_31_26`"
#    echo -e "I[25-21]\t`converte $1 $I_25_21`"
#    echo -e "I[20-16]\t`converte $1 $I_20_16`"
#    echo -e "I[15-11]\t`converte $1 $I_15_11`"
#    echo -e "I[15-0]\t\t`converte $1 $I_15_0`"
#    #sinais nao sao convertidos
#    echo -e "RedDst\t\t$RedDst"
#    echo -e "Branch\t\t$Branch"
#    echo -e "MemRead\t\t$MemRead"
#       echo -e "MemWrite\t$MemWrite"
#       echo -e "MemtoReg\t$MemtoReg"
#       echo -e "AluOp\t\t`converte $1 $AluOp`" 
#       echo -e "AluOperation\t`converte $1 $AluOperation`"
#       echo -e "AluSrc\t\t$AluSrc"
#       echo -e "RegWrite\t$RegWrite" 
#       
#       echo -e "Read_data1\t`converte $1 $Read_data1`"
#       echo -e "Read_data2\t`converte $1 $Read_data2`"
#       echo -e "Read_data\t`converte $1 $Read_data`"
#    Write_Data32=`completaNum $Write_Data 32`
#    AluResult32=`completaNum $result 32`
#       echo -e "Write_Data\t`converte $1 $Write_Data32`" #$Write_Data" 
#       echo -e "AluResult\t`converte $1 $AluResult32`"
#       
#       #cat $register 
#}







