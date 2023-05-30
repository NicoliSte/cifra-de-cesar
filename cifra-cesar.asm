.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\masm32.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\masm32.lib


.data
menuPrompt db "Escolha uma opcao: ", 0
menuOptions db "1. Criptografar ", 0
            db " 2. Descriptografar ", 0
            db " 3. Sair ", 0
            db " 4. Criptoanalise ", 0
menuLength equ $ - menuOptions
userChoice db 5 dup(?)

filePrompt db "Digite o nome do arquivo de entrada: ", 0
outputPrompt db "Digite o nome do arquivo de saida: ", 0
keyPrompt db "Digite a chave de criptografia (1-20): ", 0
newLine db 0Dh, 0Ah, 0

filenameInput db 256 dup(0)
outputFile db 256 dup(0)
keyInput db 5 dup(0)
buffer db 512 dup(0)
fileBuffer db 512 dup(0)
encryptedBuffer db 512 dup(0)
fileSize DWORD ? ; Tamanho do arquivo de entrada
letterFrequency DWORD 26 dup(0) ; Tabela de frequência das letras
portugueseFrequency DWORD 417836 ; Frequência esperada das letras em um texto em português
keyPrompt2 db "A chave correta para descriptografar o arquivo e: ", 0
keyFormat db "%d", 0
keyOutputSize equ 16
outputBuffer db keyOutputSize dup(0)
correctKey DWORD ? ; Definição da variável correctKey como DWORD (4 bytes)

bytesWritten dd 0
consoleWrite dd 0
bytesRead dd 0
deslocamento db ?

erroLeitura db "Erro ao ler a entrada. Reinicie o programa.", 0
invalidFileMessage db "Arquivo invalido. Verifique o nome e o caminho do arquivo.", 0
invalidKeyMessage db "Chave de criptografia invalida. Digite um valor entre 1 e 20.", 0
failurePrompt db "Nenhuma chave correta encontrada.", 0
confirm db "Operacao bem sucedida.", 0

inputFileHandle HANDLE ?
outputFileHandle HANDLE ?

inputHandle HANDLE 0
outputHandle HANDLE 0


.code
start:
     ; Solicitar handle de entrada
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov inputHandle, eax

    ; Solicitar handle de saída
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov outputHandle, eax
    
    ; Configurar e exibir o prompt do menu
    invoke WriteConsole, outputHandle, offset newLine, sizeof newLine - 1, offset consoleWrite, 0
    invoke WriteConsole, outputHandle, offset menuPrompt, sizeof menuPrompt - 1, offset consoleWrite, 0

    ; Exibir as opções do menu
    invoke WriteConsole, outputHandle, offset menuOptions, menuLength, offset consoleWrite, 0
    invoke WriteConsole, outputHandle, offset newLine, sizeof newLine - 1, offset consoleWrite, 0

    ; Ler a escolha do usuário
    invoke ReadConsole, inputHandle, offset userChoice, sizeof userChoice, offset consoleWrite, 0

    ; Processar a escolha do usuário
    cmp byte ptr[userChoice], "1"
    je opcao1
    cmp byte ptr[userChoice], "2"
    je opcao2
    cmp byte ptr[userChoice], "3"
    je opcao3
    cmp byte ptr[userChoice], "4"
    je opcao4

    ; Escolha inválida
    jmp sair

opcao1:
    ; Código para a opção 1 (criptografar)
    invoke WriteConsole, outputHandle, offset filePrompt, sizeof filePrompt - 1, offset consoleWrite, 0

    ; Ler o nome do arquivo de entrada
    invoke ReadConsole, inputHandle, addr filenameInput, sizeof filenameInput - 1,addr consoleWrite , 0

    ; Remover o caractere Enter da string lida do nome do arquivo de entrada
    mov esi, offset filenameInput ; Armazenar apontador da string em esi
    proximo:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximo
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Abrir o arquivo de entrada
    invoke CreateFile, offset filenameInput, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je arquivoInvalido

    ; Salvar o arquivo de entrada no handle inputFileHandle
    mov inputFileHandle, eax

    ; Solicitar o nome do arquivo de saída
    invoke WriteConsole, outputHandle, offset outputPrompt, sizeof outputPrompt - 1, offset consoleWrite, 0

    ; Ler o nome do arquivo de saída
    invoke ReadConsole, inputHandle, addr outputFile, sizeof outputFile - 1, addr consoleWrite, 0

    ; Remover o caractere Enter da string lida do nome do arquivo de entrada
    mov esi, offset outputFile ; Armazenar apontador da string em esi
    proximo_s:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximo_s
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Criar o arquivo de saída
    invoke CreateFile, offset outputFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je arquivoInvalido

    ; Salvar o arquivo de saída no handle outputFileHandle
    mov outputFileHandle, eax

    ; Solicitar a chave de criptografia
    invoke WriteConsole, outputHandle, offset keyPrompt, sizeof keyPrompt - 1, offset consoleWrite, 0

    ; Ler a chave de criptografia
    invoke ReadConsole, inputHandle, addr keyInput, sizeof keyInput - 1, addr consoleWrite, 0

    ; Remover o caractere Enter da string lida da chave de criptografia
    mov esi, offset keyInput ; Armazenar o ponteiro da string em esi
    proximo_k:
    mov al, [esi] ; Mover o caractere atual para al
    inc esi ; Apontar para o próximo caractere
    cmp al, 13 ; Verificar se é o caractere ASCII CR - FINALIZAR
    jne proximo_k
    dec esi ; Apontar para o caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Converter a chave de criptografia para um numero
    invoke atodw, addr keyInput

    ; Lógica de criptografia
    mov deslocamento, al ; Armazenar a chave de criptografia em deslocamento
    
    ; Lógica de criptografia
    mov esi, offset buffer ; Apontar para o buffer de leitura/escrita
    mov ecx, sizeof buffer ; Tamanho do buffer
    mov bytesRead, 0 ; Zerar a contagem de bytes lidos
    
    while_loop:
        ; Ler do arquivo de entrada para o buffer
        invoke ReadFile, inputFileHandle, addr fileBuffer, sizeof fileBuffer, addr bytesRead, NULL

        ; Verificar se chegou ao fim do arquivo
        cmp bytesRead, 0
        je end_while

        ; Criptografar os dados no buffer
        xor ecx, ecx ; Zerar ecx
        mov cl, deslocamento ; Mover o valor do deslocamento para cl

        mov esi, offset fileBuffer ; Apontar para o buffer de leitura
        mov edi, offset encryptedBuffer ; Apontar para o buffer de escrita

        mov ebx, bytesRead ; Salvar a contagem de bytes lidos em ebx

        ; Loop para criptografar byte a byte
            for_loop:
            mov al, [esi+ebx-1] ; Mover o byte atual para al
            add al, cl ; Criptografar o byte usando o deslocamento
            mov [edi+ebx-1], al ; Salvar o byte criptografado no buffer de escrita
            dec ebx   ; Decrementar o contador de bytes
            cmp ebx, 0   ; Verificar se o contador chegou a zero
            jnz for_loop   ; Se não chegou, saltar para o rótulo for_loop

        ; Escrever o conteúdo criptografado no arquivo de saída
        invoke WriteFile, outputFileHandle, addr encryptedBuffer, bytesRead, addr bytesWritten, NULL

        ; Reiniciar os buffers
        xor esi, esi ; Zerar esi (buffer de leitura)
        xor edi, edi ; Zerar edi (buffer de escrita)

        jmp while_loop

   end_while:
   ; Fechar os handles dos arquivos antes de sair
   invoke CloseHandle, inputFileHandle
   invoke CloseHandle, outputFileHandle 
   invoke WriteConsole, outputHandle, offset newLine, sizeof newLine - 1, offset consoleWrite, 0
   jmp deucerto
   

opcao2:
   
    ; Código para a opção 1 (descriptografar)
    invoke WriteConsole, outputHandle, offset filePrompt, sizeof filePrompt - 1, offset consoleWrite, 0

    ; Ler o nome do arquivo de entrada
    invoke ReadConsole, inputHandle, addr filenameInput, sizeof filenameInput - 1,addr consoleWrite , 0

    ; Remover o caractere Enter da string lida do nome do arquivo de entrada
    mov esi, offset filenameInput ; Armazenar apontador da string em esi
    proximod:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximod
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Abrir o arquivo de entrada
    invoke CreateFile, offset filenameInput, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je arquivoInvalido

    ; Salvar o arquivo de entrada no handle inputFileHandle
    mov inputFileHandle, eax

    ; Solicitar o nome do arquivo de saída
    invoke WriteConsole, outputHandle, offset outputPrompt, sizeof outputPrompt - 1, offset consoleWrite, 0

    ; Ler o nome do arquivo de saída
    invoke ReadConsole, inputHandle, addr outputFile, sizeof outputFile - 1, addr consoleWrite, 0

    ; Remover o caractere Enter da string lida do nome do arquivo de entrada
    mov esi, offset outputFile ; Armazenar apontador da string em esi
    proximo_sd:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximo_sd
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Criar o arquivo de saída
    invoke CreateFile, offset outputFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je arquivoInvalido

    ; Salvar o arquivo de saída no handle outputFileHandle
    mov outputFileHandle, eax

    ; Solicitar a chave de criptografia
    invoke WriteConsole, outputHandle, offset keyPrompt, sizeof keyPrompt - 1, offset consoleWrite, 0

    ; Ler a chave de criptografia
    invoke ReadConsole, inputHandle, addr keyInput, sizeof keyInput - 1, addr consoleWrite, 0

    ; Remover o caractere Enter da string lida da chave de criptografia
    mov esi, offset keyInput ; Armazenar o ponteiro da string em esi
    proximo_kd:
    mov al, [esi] ; Mover o caractere atual para al
    inc esi ; Apontar para o próximo caractere
    cmp al, 13 ; Verificar se é o caractere ASCII CR - FINALIZAR
    jne proximo_kd
    dec esi ; Apontar para o caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Converter a chave de criptografia para um numero
    invoke atodw, addr keyInput

    ; Lógica de criptografia
    mov deslocamento, al ; Armazenar a chave de criptografia em deslocamento
    mov esi, offset buffer ; Apontar para o buffer de leitura/escrita
    mov ecx, sizeof buffer ; Tamanho do buffer
    mov bytesRead, 0 ; Zerar a contagem de bytes lidos
    
    while_loop2:
        ; Ler do arquivo de entrada para o buffer
        invoke ReadFile, inputFileHandle, addr fileBuffer, sizeof fileBuffer, addr bytesRead, NULL

        ; Verificar se chegou ao fim do arquivo
        cmp bytesRead, 0
        je end_while2

        ; Criptografar os dados no buffer
        xor ecx, ecx ; Zerar ecx
        mov cl, deslocamento ; Mover o valor do deslocamento para cl

        mov esi, offset fileBuffer ; Apontar para o buffer de leitura
        mov edi, offset encryptedBuffer ; Apontar para o buffer de escrita

        mov ebx, bytesRead ; Salvar a contagem de bytes lidos em ebx

        ; Loop para criptografar byte a byte
            for_loop2:
            mov al, [esi+ebx-1] ; Mover o byte atual para al
            sub al, cl ; Criptografar o byte usando o deslocamento
            mov [edi+ebx-1], al ; Salvar o byte criptografado no buffer de escrita
            dec ebx   ; incrementar o contador de bytes
            cmp ebx, 0   ; Verificar se o contador chegou a zero
            jnz for_loop2   ; Se não chegou, saltar para o rótulo for_loop

        ; Escrever o conteúdo criptografado no arquivo de saída
        invoke WriteFile, outputFileHandle, addr encryptedBuffer, bytesRead, addr bytesWritten, NULL

        ; Reiniciar os buffers
        xor esi, esi ; Zerar esi (buffer de leitura)
        xor edi, edi ; Zerar edi (buffer de escrita)

        jmp while_loop2

   end_while2:
   ; Fechar os handles dos arquivos antes de sair
   invoke CloseHandle, inputFileHandle
   invoke CloseHandle, outputFileHandle 
   invoke WriteConsole, outputHandle, offset newLine, sizeof newLine - 1, offset consoleWrite, 0
   jmp deucerto

    
opcao3:
    
    jmp sair

opcao4:
    ; Código para a(criptoanalise)
    invoke WriteConsole, outputHandle, offset filePrompt, sizeof filePrompt - 1, offset consoleWrite, 0

    ; Ler o nome do arquivo de entrada
    invoke ReadConsole, inputHandle, addr filenameInput, sizeof filenameInput - 1,addr consoleWrite , 0

    ; Remover o caractere Enter da string lida do nome do arquivo de entrada
    mov esi, offset filenameInput ; Armazenar apontador da string em esi
    proximoca:
    mov al, [esi] ; Mover caractere atual para al
    inc esi ; Apontar para o proximo caractere
    cmp al, 13 ; Verificar se eh o caractere ASCII CR - FINALIZAR
    jne proximoca
    dec esi ; Apontar para caractere anterior
    xor al, al ; ASCII 0
    mov [esi], al ; Inserir ASCII 0 no lugar do ASCII CR

    ; Abrir o arquivo de entrada
    invoke CreateFile, offset filenameInput, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je arquivoInvalido

    ; Salvar o arquivo de entrada no handle inputFileHandle
    mov inputFileHandle, eax

    ; Obter o tamanho do arquivo
    invoke GetFileSize, inputFileHandle, NULL
    mov fileSize, eax

    ; Variáveis para contagem de frequência das letras
    mov ecx, 26 ; Número de letras do alfabeto
    mov esi, 0 ; Índice para percorrer o alfabeto
    mov edi, offset letterFrequency ; Endereço da tabela de frequência das letras

   clearFrequency:
    mov dword ptr [edi], 0 ; Preencher o elemento atual da tabela com zero
    add edi, 4 ; Avançar para o próximo elemento
    loop clearFrequency ; Repetir até percorrer todos os elementos da tabela

    ; Ler o arquivo de entrada e contar a frequência das letras
    mov ecx, fileSize ; Tamanho do arquivo
    mov edi, offset fileBuffer ; Buffer para armazenar o conteúdo do arquivo

    readFileLoop:
    invoke ReadFile, inputFileHandle, edi, 1, addr bytesRead, NULL
    cmp bytesRead, 0 ; Verificar se chegou ao fim do arquivo
    je frequencyAnalysis

    ; Atualizar a tabela de frequência das letras
    movzx eax, byte ptr [edi] ; Converter o byte lido para um valor entre 0 e 255
    cmp eax, 'A' ; Verificar se é uma letra maiúscula
    jb notUppercase
    cmp eax, 'Z'
    ja notUppercase
    sub eax, 'A' ; Converter a letra para um índice de 0 a 25
    jmp updateFrequency

    notUppercase:
    cmp eax, 'a' ; Verificar se é uma letra minúscula
    jb notLetter
    cmp eax, 'z'
    ja notLetter
    sub eax, 'a' ; Converter a letra para um índice de 0 a 25
    jmp updateFrequency

    notLetter:
    jmp nextByte

    updateFrequency:
    shl eax, 2 ; Multiplicar o índice por 4 para apontar corretamente na tabela de frequência
    add eax, offset letterFrequency ; Adicionar o deslocamento para a tabela de frequência
    inc dword ptr [eax] ; Incrementar a frequência da letra correspondente

    nextByte:
    add edi, 1 ; Avançar para o próximo byte
    loop readFileLoop

    frequencyAnalysis:
    ; Realizar a criptoanálise para encontrar a chave correta
    mov ecx, 21 ; Número de chaves a serem testadas (de 0 a 20)
    mov esi, 0 ; Índice para percorrer as chaves (de 0 a 20)
    mov edi, offset letterFrequency ; Endereço da tabela de frequência das letras

    findKeyLoop:
    push ecx ; Salvar o contador para uso posterior

    ; Calcular a soma das frequências das letras da mensagem original em português
    mov eax, 0 ; Variável para armazenar a soma
    mov ebx, 0 ; Índice para percorrer a tabela de frequência das letras

    sumFrequencies:
    add eax, dword ptr [edi + ebx]
    add ebx, 4
    loop sumFrequencies

    ; Comparar a soma das frequências com o valor esperado para o português
    cmp eax, portugueseFrequency
    je foundKey

    ; Caso a chave não seja encontrada, avançar para a próxima chave
    pop ecx ; Restaurar o contador
    inc esi ; Avançar para a próxima chave
    jmp checkNextKey

    foundKey:
    ; A chave correta foi encontrada, armazenar o valor em uma variável
    mov correctKey, esi

    checkNextKey:
     loop findKeyLoop

    ; Exibir a chave correta
    invoke WriteConsole, outputHandle, offset keyPrompt2, sizeof keyPrompt2 - 1, offset consoleWrite, 0
    invoke wsprintf, addr outputBuffer, addr keyFormat, correctKey
    invoke WriteConsole, outputHandle, addr outputBuffer, keyOutputSize, offset consoleWrite, 0

    ; Fechar o arquivo de entrada
    invoke CloseHandle, inputFileHandle

    ; Retornar ao ponto de entrada do programa
    je deucerto


arquivoInvalido:
    ; Exibir mensagem de arquivo inválido
    invoke WriteConsole, outputHandle, offset invalidFileMessage, sizeof invalidFileMessage - 1, offset consoleWrite, 0
    jmp start

chaveInvalida:
    ; Exibir mensagem de chave inválida
    invoke WriteConsole, outputHandle, offset invalidKeyMessage, sizeof invalidKeyMessage - 1, offset consoleWrite, 0
    jmp start

deucerto:
    ; Exibir mensagem que deu certo
    invoke WriteConsole, outputHandle, offset confirm, sizeof confirm - 1, offset consoleWrite, 0
    jmp start

leituraFalhou:
    ; Exibir mensagem de erro de leitura
    invoke WriteConsole, outputHandle, offset erroLeitura, sizeof erroLeitura - 1, offset consoleWrite, 0
    jmp start

sair:

    ; Sair do programa
    invoke ExitProcess, 0

end start
