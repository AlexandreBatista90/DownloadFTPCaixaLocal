unit DownloadCaixaLocal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, System.ImageList, Vcl.ImgList, System.Types, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdExplicitTLSClientServerBase,
  IdFTP, IdFTPList, IdFTPCommon , IdAllFTPListParsers, System.Win.TaskbarCore,
  Vcl.Taskbar, System.DateUtils, Winapi.CommCtrl, Winapi.ShellAPI,
  IdAntiFreezeBase, IdAntiFreeze, System.IOUtils, IdSSLOpenSSLHeaders,
  Vcl.WinXCtrls, UnitSobre, IdException, ConfigCredenciais;

type
  TDownloadFTP_CaixaLocal = class(TForm)
    lblPastaFTP: TLabel;
    Edit1: TEdit;
    btnConectar: TButton;
    lvArquivos: TListView;
    pnlDireita: TPanel;
    Panel2: TPanel;
    pbDownload: TProgressBar;
    lbSalver: TLabel;
    edtDestino: TEdit;
    lblProgresso: TLabel;
    pnlTop: TPanel;
    ImageList1: TImageList;
    IdFTP1: TIdFTP;
    IdSSLIOHandlerSocketOpenSSL1: TIdSSLIOHandlerSocketOpenSSL;
    FileOpenDialog1: TFileOpenDialog;
    BitBtn1: TBitBtn;
    Taskbar1: TTaskbar;
    btnAbrirNoExplorer: TSpeedButton;
    IdAntiFreeze1: TIdAntiFreeze;
    btnDownload: TSpeedButton;
    imgBotoes: TImageList;
    pnlLoading: TPanel;
    ActivityIndicator1: TActivityIndicator;
    pnlSobre: TPanel;
    btnSobre: TSpeedButton;
    edtSenha: TEdit;
    btnConfirmarSenha: TSpeedButton;
    lblSenhaExclusiva: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnConectarClick(Sender: TObject);
    procedure lvArquivosDblClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure btnDownloadClick(Sender: TObject);
    procedure IdFTP1WorkBegin(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCountMax: Int64);
    procedure IdFTP1Work(ASender: TObject; AWorkMode: TWorkMode;
      AWorkCount: Int64);
    procedure IdFTP1WorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure lvArquivosColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvArquivosCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure lvArquivosSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure btnAbrirNoExplorerClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnSobreClick(Sender: TObject);
    procedure btnConfirmarSenhaClick(Sender: TObject);
    procedure lvArquivosKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure edtSenhaKeyPress(Sender: TObject; var Key: Char);

  private
    { Private declarations }
    FSortColumn: Integer;    // Guarda o índice da coluna clicada (0, 1 ou 2)
    FSortAscending: Boolean; // True para crescente, False para decrescente
    FCarregando: Boolean;
    FDownloadEmAndamento: Boolean; // Bloqueia o fechamento e os botões
    FArquivoAtual: string;        // Guarda o caminho do arquivo para deletar se cancelar
    FArquivoTemporario: string;
    FTamanhoArquivoAtual: Int64;
    FBytesJaBaixados: Int64;
    FPararConexao: Boolean;
    FSenhaLiberada: Boolean;



    procedure AtualizarSetasOrdenacao;
    procedure ConectarEmSegundoPlano;
    procedure AtualizarListaEmSegundoPlano;

  public
    { Public declarations }
  end;

var
  DownloadFTP_CaixaLocal: TDownloadFTP_CaixaLocal;

implementation

{$R *.dfm}

procedure TDownloadFTP_CaixaLocal.ConectarEmSegundoPlano;
begin
  // 1. PREPARAÇÃO VISUAL (Roda na linha principal)
  FCarregando := True;
  pnlLoading.BringToFront;
  pnlLoading.Visible := True;
  btnConectar.Enabled := False;
  lvArquivos.Items.Clear;

  // 2. DISPARA A THREAD DE REDE
  TThread.CreateAnonymousThread(procedure
  var
    ErroMsg: string;
  begin
    ErroMsg := '';
    try
      if FPararConexao then Exit;
      // Garante que desconectou antes de tentar de novo
      if IdFTP1.Connected then IdFTP1.Disconnect;

      // Suas configurações de conexão
      IdFTP1.Host := FTP_HOST;
      IdFTP1.Port := 21;
      IdFTP1.Username := FTP_USER;
      IdFTP1.Password := FTP_PASS;
      IdFTP1.Passive := True;
      IdFTP1.IOHandler := IdSSLIOHandlerSocketOpenSSL1;
      IdFTP1.UseTLS := TIdUseTLS.utUseExplicitTLS;
      IdFTP1.DataPortProtection := TIdFTPDataPortSecurity.ftpdpsPrivate;
      IdSSLIOHandlerSocketOpenSSL1.SSLOptions.Method := TIdSSLVersion.sslvTLSv1_2;
      IdSSLIOHandlerSocketOpenSSL1.SSLOptions.Mode := TIdSSLMode.sslmClient;

      // Conecta e puxa a lista (ISTO É O QUE DEMORA OS 7 SEGUNDOS)
      IdFTP1.Connect;
      if FPararConexao then Exit; // Se o usuário fechou, sai da Thread imediatamente!
      IdFTP1.ChangeDir('/CAIXALOCAL/');
      IdFTP1.List;
      if FPararConexao then Exit;

    except
      on E: EIdConnClosedGracefully do
      begin
        // IGNORA COMPLETAMENTE. É apenas o Indy avisando que a gente fechou a porta.
      end;
      on E: Exception do
      begin
        // Se o usuário pediu para fechar (FPararConexao) , ignora erro
        if (not FPararConexao) and (Pos('Gracefully', E.Message) = 0) then
          ErroMsg := E.Message;
      end;
    end;

    // 3. SINCRONIZA COM A TELA (Atualiza o visual com os dados que a rede baixou)
    TThread.Synchronize(nil, procedure
    var
      i: Integer;
    begin
      if FPararConexao then Exit;
      if ErroMsg <> '' then
      begin
        ShowMessage('Erro na conexão FTP: ' + ErroMsg);
        if IdFTP1.Connected then IdFTP1.Disconnect;
      end
      else
      begin
        // Preenche o TListView visualmente
        lvArquivos.Items.BeginUpdate;
        try
          for i := 0 to IdFTP1.DirectoryListing.Count - 1 do
          begin
            with lvArquivos.Items.Add do
            begin
              Caption := IdFTP1.DirectoryListing[i].FileName;
              SubItems.Add(FormatFloat('#,##0.00 MB', IdFTP1.DirectoryListing[i].Size / 1048576));
              SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', TTimeZone.Local.ToLocalTime(IdFTP1.DirectoryListing[i].ModifiedDate)));
            end;
          end;
        finally
          lvArquivos.Items.EndUpdate;
        end;

        // Ordena por data mais recente
        FSortColumn := 2;
        FSortAscending := False;
        lvArquivos.AlphaSort;
        AtualizarSetasOrdenacao;
      end;

      // 4. FINALIZAÇÃO E AVALIAÇÃO DA SENHA
      FCarregando := False;

      btnConectar.Enabled := FSenhaLiberada;
      btnDownload.Enabled := FSenhaLiberada and (lvArquivos.Selected <> nil);

      // AVALIAÇÃO DE TEMPO: senha
      if FSenhaLiberada then
      begin
        pnlLoading.Visible := False;
      end;

    end);
  end).Start;
end;

procedure TDownloadFTP_CaixaLocal.edtSenhaKeyPress(Sender: TObject;
  var Key: Char);
begin
  // #13 >> código do 'enter'
  if Key = #13 then
  begin
    Key := #0; // Anula a tecla para o Windows não fazer aquele som de "Erro/Beep"
    btnConfirmarSenhaClick(Self); // Chama o clique do botão diretamente
  end;
end;

procedure TDownloadFTP_CaixaLocal.AtualizarListaEmSegundoPlano;
begin
  // 1. VALIDAÇÃO RÁPIDA E RECONEXÃO AUTOMÁTICA
  if not IdFTP1.Connected then
  begin
    // Se a conexão caiu ou não existe, chama a função completa que
    // já conecta e já lista os arquivos, e aborta a continuação desta.
    if FPararConexao then Exit;
    ConectarEmSegundoPlano;
    Exit;
  end;

  if FDownloadEmAndamento then
  begin
    ShowMessage('Aguarde o download terminar para atualizar a lista.');
    Exit;
  end;

  // 2. PREPARAÇÃO VISUAL
  btnConectar.Enabled := False;
  FCarregando := True;
  pnlLoading.BringToFront;
  pnlLoading.Visible := True;
  lvArquivos.Items.Clear;
  if FPararConexao then Exit;

  // 3. DISPARA A THREAD DE REDE (Trabalho leve rodando no fundo)
  TThread.CreateAnonymousThread(procedure
  var
    ErroMsg: string;
  begin
    ErroMsg := '';
    try
      if FPararConexao then Exit;
      // Comando instantâneo: Pede a lista da pasta atual
      IdFTP1.List;
      if FPararConexao then Exit;
    except
      on E: Exception do
        ErroMsg := E.Message;
    end;

    // 4. SINCRONIZA COM A TELA (Atualiza o visual)
    TThread.Synchronize(nil, procedure
    var
      i: Integer;
    begin
      if ErroMsg <> '' then
      begin
        ShowMessage('Erro ao atualizar a lista: ' + ErroMsg);
        // Se deu erro ao listar (ex: a internet do cliente caiu do nada),
        // força o disconnect para que no próximo clique ele reconecte do zero.
        if IdFTP1.Connected then IdFTP1.Disconnect;
      end
      else
      begin
        // Preenche o TListView visualmente com a nova lista
        lvArquivos.Items.BeginUpdate;
        try
          for i := 0 to IdFTP1.DirectoryListing.Count - 1 do
          begin
            with lvArquivos.Items.Add do
            begin
              Caption := IdFTP1.DirectoryListing[i].FileName;
              SubItems.Add(FormatFloat('#,##0.00 MB', IdFTP1.DirectoryListing[i].Size / 1048576));
              SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', TTimeZone.Local.ToLocalTime(IdFTP1.DirectoryListing[i].ModifiedDate)));
            end;
          end;
        finally
          lvArquivos.Items.EndUpdate;
          btnConectar.Enabled := True;
        end;

        // Mantém a ordenação que o usuário tinha escolhido
        lvArquivos.AlphaSort;
        AtualizarSetasOrdenacao;
      end;

      // 5. FINALIZAÇÃO E EFEITO DE SUMIR O LOADING
      btnDownload.Enabled := (lvArquivos.Selected <> nil);
      pnlLoading.Visible := False;
      FCarregando := False;

    end);
  end).Start;
end;



procedure TDownloadFTP_CaixaLocal.AtualizarSetasOrdenacao;
var
  I: Integer;
  HeaderHandle: HWND;
  HDItem: THDItem;
begin
  // 1. Pega a "alça" (Handle) do controle nativo de cabeçalho do Windows
  HeaderHandle := SendMessage(lvArquivos.Handle, LVM_GETHEADER, 0, 0);

  if HeaderHandle = 0 then
    Exit; // Proteção caso o cabeçalho não exista

  // 2. Percorre todas as colunas para limpar as setas antigas e colocar a nova
  for I := 0 to lvArquivos.Columns.Count - 1 do
  begin
    ZeroMemory(@HDItem, SizeOf(HDItem));
    HDItem.Mask := HDI_FORMAT;

    // Lê o formato atual da coluna
    SendMessage(HeaderHandle, HDM_GETITEM, I, LPARAM(@HDItem));

    // Limpa qualquer seta que já exista (UP ou DOWN) usando operadores binários
    HDItem.fmt := HDItem.fmt and not (HDF_SORTUP or HDF_SORTDOWN);

    // Se for a coluna que estamos ordenando agora, adiciona a seta correta
    if I = FSortColumn then
    begin
      if FSortAscending then
        HDItem.fmt := HDItem.fmt or HDF_SORTUP     // Seta para cima
      else
        HDItem.fmt := HDItem.fmt or HDF_SORTDOWN;  // Seta para baixo
    end;

    // Devolve o formato atualizado para a coluna no Windows
    SendMessage(HeaderHandle, HDM_SETITEM, I, LPARAM(@HDItem));
  end;
end;

procedure TDownloadFTP_CaixaLocal.BitBtn1Click(Sender: TObject);
begin
  // Configura o diálogo para selecionar APENAS pastas, ignorando arquivos soltos
  FileOpenDialog1.Options := [TFileDialogOption.fdoPickFolders];

  // Abre a janela de seleção
  if FileOpenDialog1.Execute then
  begin
    // Salva o caminho selecionado dentro do seu TEdit (ajuste o nome do seu Edit aqui)
    edtDestino.Text := FileOpenDialog1.FileName;
  end;
  // Tira o foco do botão e "devolve" para o formulário
  Self.ActiveControl := nil;
end;

procedure TDownloadFTP_CaixaLocal.btnConectarClick(Sender: TObject);
begin
  // Chama a atualização rápida em segundo plano
  AtualizarListaEmSegundoPlano;

  // Tira o foco do botão e "devolve" para o formulário
  Self.ActiveControl := nil;
end;

procedure TDownloadFTP_CaixaLocal.btnConfirmarSenhaClick(Sender: TObject);
begin
  // ANTI-SPAM: Se já estiver liberado, ignora qualquer duplo clique acidental ou excesso de "Enters"
  if FSenhaLiberada then Exit;

  if edtSenha.Text = SENHA_APP then
  begin
    FSenhaLiberada := True;

    // Oculta os 3 elementos visuais da senha de uma vez
    edtSenha.Visible := False;
    btnConfirmarSenha.Visible := False;
    lblSenhaExclusiva.Visible := False; // Seu novo label some aqui!

    // Destrava os botões secundários
    btnSobre.Enabled := True;
    btnAbrirNoExplorer.Enabled := True;
    BitBtn1.Enabled := True;

    // AVALIAÇÃO DE TEMPO
    if not FCarregando then
    begin
      pnlLoading.Visible := False;
      btnConectar.Enabled := True;
    end
    else
    begin
      // A REDE AINDA ESTÁ TRABALHANDO: Mostra o indicador girando agora!
      ActivityIndicator1.Visible := True;
    end;
  end
  else
  begin
    ShowMessage('Senha incorreta! Acesso negado.');
    edtSenha.Clear;
    if edtSenha.CanFocus then
      edtSenha.SetFocus;
  end;
end;

procedure TDownloadFTP_CaixaLocal.btnDownloadClick(Sender: TObject);
var
  NomeArquivo, CaminhoLocal, CaminhoCompletoDestino: string;
  i: Integer;
begin
  // 1. VALIDAÇÕES PRELIMINARES (Roda na Thread Principal - Rápido)
  if not IdFTP1.Connected then
  begin
    ShowMessage('Por favor, conecte-se ao FTP primeiro!');
    Exit;
  end;

  if lvArquivos.Selected = nil then
  begin
    ShowMessage('Selecione um arquivo na lista para fazer o download.');
    Exit;
  end;

  if Trim(edtDestino.Text) = '' then
  begin
    ShowMessage('Selecione uma pasta de destino antes de baixar.');
    Exit;
  end;

  CaminhoLocal := IncludeTrailingPathDelimiter(edtDestino.Text);

// Verifica existência da pasta
if not DirectoryExists(CaminhoLocal) then
begin
  // Usamos Application.MessageBox para ter controle total do título
  // O parâmetro 'Confirmação' é o título da janela.
  // MB_YESNO cria os botões Sim/Não.
  // MB_ICONQUESTION coloca o ícone de interrogação azul.
  if Application.MessageBox(PChar('A pasta "' + CaminhoLocal + '" não existe.' + #13#10 +
                                  'Deseja criá-la agora?'),
                            'Confirmação',
                            MB_YESNO + MB_ICONQUESTION) = IDYES then
  begin
    // Se o usuário aceitou, tenta criar a pasta
    if not ForceDirectories(CaminhoLocal) then
    begin
        ShowMessage('Erro: Não foi possível criar a pasta.');
        Exit;
      end;
    end
    else Exit;
  end;

  NomeArquivo := lvArquivos.Selected.Caption;
  CaminhoCompletoDestino := CaminhoLocal + NomeArquivo;
  FArquivoAtual := CaminhoCompletoDestino;
  FArquivoTemporario := CaminhoCompletoDestino + '.part';

  // if FileExists(FArquivoTemporario) then     > COMENTADO PARA TENTATIVA DE IMPLEMENTAR A 'CONTINUACAO' DO DOWNLOAD QUANDO DÁ ALGUA FALHA
  //  DeleteFile(FArquivoTemporario);

  // --- NOVA LÓGICA: RESGATAR O TAMANHO REAL DO ARQUIVO DA MEMÓRIA ---
  FTamanhoArquivoAtual := 0;
  for i := 0 to IdFTP1.DirectoryListing.Count - 1 do
  begin
    if IdFTP1.DirectoryListing[i].FileName = NomeArquivo then
    begin
      FTamanhoArquivoAtual := IdFTP1.DirectoryListing[i].Size; // Pega os bytes exatos
      Break;
    end;
  end;
  // ------------------------------------------------------------------

  // Verifica arquivo existente
  if FileExists(CaminhoCompletoDestino) then
  begin
    // Usamos MessageBox para ter controle do título "Confirmação"
    if Application.MessageBox(PChar('O arquivo "' + NomeArquivo + '" já existe na pasta de destino.' + #13#10 +
                                    'Deseja substituí-lo?'),
                              'Confirmação',
                              MB_YESNO + MB_ICONQUESTION) = IDYES then
    begin
      // Se clicou em SIM, nós APAGAMOS o arquivo antigo manualmente antes do FTP baixar.
      if not DeleteFile(CaminhoCompletoDestino) then
      begin
        Application.MessageBox('Não foi possível substituir. O arquivo antigo deve estar aberto em outro programa.', 'Erro', MB_OK + MB_ICONERROR);
        Exit;
      end;
    end
    else
    begin
      // Se clicou em NÃO, cancela tudo e sai
      Exit;
    end;
  end;

  // 2. DISPARA A THREAD DE DOWNLOAD
  NomeArquivo := lvArquivos.Selected.Caption;
  FArquivoAtual := CaminhoLocal + NomeArquivo; // Salva o nome na variável global da classe

  // BLOQUEIA A INTERFACE
  FDownloadEmAndamento := True;
  btnConectar.Enabled := False;
  btnDownload.Enabled := False; // Bloqueia o botão para não clicar duas vezes

  TThread.CreateAnonymousThread(procedure
  var
    Sucesso, Continuar: Boolean;
    MsgErro: string;
    Tentativas: Integer;
    LStream: TFileStream;
    InfoPiscar: TFlashWInfo;
  begin
    Sucesso := False;
    MsgErro := '';
    Tentativas := 0;

    try
      TThread.Synchronize(nil, procedure begin Screen.Cursor := crHourGlass; end);

      while (not Sucesso) and FDownloadEmAndamento do
      begin
        try
          // 1. Reconecta se necessário
          if not IdFTP1.Connected then
          begin
            TThread.Synchronize(nil, procedure begin
              pbDownload.Visible := True;
              lblProgresso.Visible := True;
              lblProgresso.Caption := 'Reconectando ao servidor...';
            end);
            IdFTP1.Connect;
            IdFTP1.ChangeDir('/CAIXALOCAL/');
          end;

          // 2. CRIA O STREAM DE ARQUIVO SEGURO
          // Se o PC foi desligado e o arquivo já existe, abre ele sem apagar.
          if FileExists(FArquivoTemporario) then
          begin
            LStream := TFileStream.Create(FArquivoTemporario, fmOpenWrite or fmShareDenyWrite);
            LStream.Seek(0, soFromEnd); // Vai pro final do arquivo
          end
          else
            LStream := TFileStream.Create(FArquivoTemporario, fmCreate or fmShareDenyWrite); // Cria um novo

          // Guarda o tamanho atual para a barra de progresso saber de onde partir
          FBytesJaBaixados := LStream.Size;

          try
            // --- A SOLUÇÃO ENTRA AQUI ---
            // Força o modo de transferência para Binário (exigência para fazer Resume)
            IdFTP1.TransferType := ftBinary;

            // 3. O COMANDO BLINDADO DO INDY COM STREAM (True = Resume)
            IdFTP1.Get(NomeArquivo, LStream, True);
            Sucesso := True; // Download 100%
          finally
            LStream.Free; // Libera o arquivo do HD na mesma hora! Evita travamentos.
          end;

        except
          on E: Exception do
          begin
            MsgErro := E.Message;
            Inc(Tentativas);

            // Se o usuário apertou "X" na tela para cancelar tudo, aborta.
            if not FDownloadEmAndamento then Break;

            // 4. LIMITE DE 5 TENTATIVAS ALCANÇADO
            if Tentativas >= 5 then
            begin
              Continuar := False;
              // Pausa a Thread e pergunta na tela do usuário
              TThread.Synchronize(nil, procedure
              begin
                if MessageDlg('Falha de Download (Erro: ' + MsgErro + ').' + #13#10 +
                              'Deseja tentar novamente?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
                  Continuar := True;
              end);

              if Continuar then
              begin
                Tentativas := 0; // O usuário quer tentar mais 5 vezes, zera o contador
              end
              else
              begin
                // O usuário clicou em NÃO. Apaga o fragmento .part e desiste.
                if FileExists(FArquivoTemporario) then
                  DeleteFile(FArquivoTemporario);
                Break; // Sai do laço while de vez
              end;
            end;

            // Se não chegou a 5, mostra ao usuário que estamos aguardando
            TThread.Synchronize(nil, procedure
            begin
              pbDownload.Visible := True;
              lblProgresso.Visible := True;
              lblProgresso.Caption := 'Tentando reconectar (' + IntToStr(Tentativas) + '/5)...';
            end);

            try if IdFTP1.Connected then IdFTP1.Disconnect; except end;
            Sleep(5000); // Aguarda 5 segundos
          end;
        end;
      end;
    finally
      TThread.Synchronize(nil, procedure begin Screen.Cursor := crDefault; end);
    end;

    // 5. FINALIZAÇÃO DA THREAD E DA TELA
    TThread.Synchronize(nil, procedure
    begin
      FDownloadEmAndamento := False;
      btnConectar.Enabled := True;
      btnDownload.Enabled := (lvArquivos.Selected <> nil); // Reativa o botão se tiver selecionado

      if Sucesso then
      begin
        InfoPiscar.cbSize := SizeOf(TFlashWInfo);
        InfoPiscar.hwnd := Self.Handle;
        InfoPiscar.dwFlags := FLASHW_ALL or FLASHW_TIMERNOFG;
        InfoPiscar.uCount := 5;
        InfoPiscar.dwTimeout := 0;
        FlashWindowEx(InfoPiscar);

        if FileExists(FArquivoAtual) then
          DeleteFile(FArquivoAtual);

        if not RenameFile(FArquivoTemporario, FArquivoAtual) then
          ShowMessage('Download concluído, mas não foi possível renomear o arquivo.')
        else
          ShowMessage('Download concluído com sucesso!');
      end
      else
      begin
        // Se chegou aqui e não teve sucesso, foi porque o usuário clicou em NÃO e o loop quebrou.
        // Apenas esconde as barras de progresso para a tela voltar ao normal.
        lblProgresso.Visible := False;
        pbDownload.Visible := False;
      end;
    end);
  end).Start;
end;

procedure TDownloadFTP_CaixaLocal.btnSobreClick(Sender: TObject);
begin
  // 1. Verifica se a janela já foi criada na memória
  if not Assigned(FormSobre) then
    FormSobre := TFormSobre.Create(Application); // Cria a tela só se ela não existir

  // 2. Mostra a tela
  FormSobre.Show;

  // 3. Opcional de luxo: Se a tela já estava aberta, mas escondida atrás
  // de alguma outra janela do Windows, isso puxa ela pra frente!
  FormSobre.BringToFront;
end;

procedure TDownloadFTP_CaixaLocal.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
var
  Tentativa: Integer;
begin
  // 1. AVISAR THREADS PARA PARAR
  FPararConexao := True;

  // 2. DESCONEXÃO SEGURA (Fazemos aqui, enquanto o componente ainda existe)
  try
    if IdFTP1.Connected then
    begin
      IdFTP1.Abort; // Interrompe o envio/recebimento
      IdFTP1.Disconnect;
    end;
  except
  end;

  // 3. MENSAGEM VISUAL SE ESTIVER TRABALHANDO
  if FDownloadEmAndamento or FCarregando then
  begin
    // Muda o label para dar feedback ao usuário
    lblProgresso.Visible := True;
    lblProgresso.Caption := 'Fechando, aguarde...';
    Application.ProcessMessages; // Atualiza a tela na hora
  end;

  CanClose := True; // Agora pode fechar, pois já desconectamos tudo!
end;


procedure TDownloadFTP_CaixaLocal.FormCreate(Sender: TObject);
var
  PastaPadrao: string;
  CaminhoTempDLL: string;
  ResStream: TResourceStream;

begin

  FSenhaLiberada := False;
  FPararConexao := False;

  // ESCONDE O INDICADOR DE CARREGAMENTO INICIALMENTE
  ActivityIndicator1.Visible := False;

  // 1. TRAVA DE SEGURANÇA INICIAL
  FSenhaLiberada := False;
  btnSobre.Enabled := False;
  btnAbrirNoExplorer.Enabled := False;
  BitBtn1.Enabled := False;
  btnConectar.Enabled := False;

  // 2. PREPARA O VISUAL DA SENHA
  edtSenha.Visible := True;
  btnConfirmarSenha.Visible := True;


// 1. DEFINE A PASTA TEMPORÁRIA: Vai criar uma pasta "FTPCaixaLocal_SSL" dentro do %TEMP% do Windows
  CaminhoTempDLL := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'FTPCaixaLocal_SSL\';
  ForceDirectories(CaminhoTempDLL);

  // 2. EXTRAI A LIBEAY32.DLL (Com proteção contra Access Violation)
  if not FileExists(CaminhoTempDLL + 'libeay32.dll') then
  begin
    try
      ResStream := TResourceStream.Create(HInstance, 'DLL_LIB', RT_RCDATA);
      try
        ResStream.SaveToFile(CaminhoTempDLL + 'libeay32.dll');
      finally
        ResStream.Free; // Libera a memória de forma segura
      end;
    except
      // Se der erro (ex: usuário abriu o programa duas vezes e o arquivo travou), ignora em silêncio
    end;
  end;

  // 3. EXTRAI A SSLEAY32.DLL
  if not FileExists(CaminhoTempDLL + 'ssleay32.dll') then
  begin
    try
      ResStream := TResourceStream.Create(HInstance, 'DLL_SSL', RT_RCDATA);
      try
        ResStream.SaveToFile(CaminhoTempDLL + 'ssleay32.dll');
      finally
        ResStream.Free;
      end;
    except
    end;
  end;

  // 4. O COMANDO DE OURO: Avisa o Indy para carregar o OpenSSL a partir da nossa pasta temporária!
  IdOpenSSLSetLibPath(CaminhoTempDLL);



  btnDownload.Enabled := (lvArquivos.Selected <> nil);
  PastaPadrao := TPath.GetDownloadsPath;
  // Joga o valor no seu Edit
  edtDestino.Text := PastaPadrao;



end;



procedure TDownloadFTP_CaixaLocal.FormDestroy(Sender: TObject);
var

  CaminhoTempDLL: string;

begin

  // 1. SEGURANÇA TOTAL: Desconecta o FTP e desvincula o handler

  try

    if IdFTP1.Connected then

      IdFTP1.Disconnect;



    // Importante: Isso diz ao FTP "esqueça o manipulador SSL"

    IdFTP1.IOHandler := nil;

  except

  end;



  // 2. AGORA sim, descarregamos a biblioteca com segurança

  try

    UnLoadOpenSSLLibrary;

  except

  end;



  // 3. Define a pasta e apaga os arquivos

  CaminhoTempDLL := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'FTPCaixaLocal_SSL\';



  // Usa Try-Finally para garantir que tentamos apagar mesmo se algo falhar

  try

    // Apaga os arquivos

    DeleteFile(CaminhoTempDLL + 'libeay32.dll');

    DeleteFile(CaminhoTempDLL + 'ssleay32.dll');



    // Remove a pasta temporária

    RemoveDir(CaminhoTempDLL);

  except

    // Ignora erros aqui, pois o Windows pode estar bloqueando a exclusão

    // por milissegundos enquanto o processo finaliza

  end;

end;








procedure TDownloadFTP_CaixaLocal.FormShow(Sender: TObject);
begin
  // O FormShow acontece 1 milissegundo depois que a tela já apareceu para o usuário.
  // Forçamos a chamada do clique do botão conectar, aproveitando todo o código que você já fez lá!

  Application.ProcessMessages; // Força o Windows a terminar de pintar a tela inteira
  ConectarEmSegundoPlano;      // Dispara a Thread invisível
  if edtSenha.CanFocus then
    edtSenha.SetFocus;

end;

procedure TDownloadFTP_CaixaLocal.IdFTP1Work(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if (not FDownloadEmAndamento) or FPararConexao then Exit;

  // O SEGREDO DO VCL STYLE: Usamos QUEUE em vez de Synchronize! (Sua lógica mantida)
  TThread.Queue(nil, procedure
  var
    TotalBaixado: Int64;
  begin
    // --- MUDANÇA AQUI ---
    // Soma o tamanho que já estava no disco com o que o Indy está baixando nesta sessão
    TotalBaixado := FBytesJaBaixados + AWorkCount;
    // --------------------

    pbDownload.Position := TotalBaixado;
    Taskbar1.ProgressValue := TotalBaixado;

    // Cálculo seguro de porcentagem (Sua lógica mantida)
    if pbDownload.Max > 1 then
      lblProgresso.Caption := 'Baixando: ' + FormatFloat('0.00', (TotalBaixado / pbDownload.Max) * 100) + '%'
    else
      // Se o tamanho for desconhecido (Max = 1), mostra apenas os MB baixados
      lblProgresso.Caption := 'Baixando: ' + FormatFloat('#,##0.00 MB', TotalBaixado / 1048576);
  end);
end;

procedure TDownloadFTP_CaixaLocal.IdFTP1WorkBegin(ASender: TObject;
  AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  if not FDownloadEmAndamento then
    Exit;

  TThread.Synchronize(nil, procedure
  var
    TamanhoReal: Int64;
  begin
    // MÁGICA (Sua lógica mantida): Se o servidor não mandou (0), usamos o tamanho que pegamos da lista!
    if AWorkCountMax > 0 then
      TamanhoReal := AWorkCountMax
    else
      TamanhoReal := FTamanhoArquivoAtual;

    // Proteção extrema contra divisão por zero (Sua lógica mantida)
    if TamanhoReal <= 0 then
      TamanhoReal := 1;

    // Alimenta as barras corretamente (Sua lógica mantida)
    pbDownload.Max := TamanhoReal;
    Taskbar1.ProgressMaxValue := TamanhoReal;

    // --- A ÚNICA MUDANÇA AQUI ---
    // Em vez de "0", a posição inicial agora é o tamanho do arquivo que já estava no HD
    pbDownload.Position := FBytesJaBaixados;
    Taskbar1.ProgressValue := FBytesJaBaixados;
    // ----------------------------

    Taskbar1.ProgressState := TTaskBarProgressState.Normal;

    lblProgresso.Caption := 'Iniciando download...';

    pbDownload.Visible := True;
    lblProgresso.Visible := True;
    pbDownload.Update;
    lblProgresso.Update;
  end);
end;

procedure TDownloadFTP_CaixaLocal.IdFTP1WorkEnd(ASender: TObject;
  AWorkMode: TWorkMode);

begin
  if not FDownloadEmAndamento then
    Exit;

  TThread.Synchronize(nil, procedure
  begin
    pbDownload.Position := pbDownload.Max;
    Taskbar1.ProgressState := TTaskBarProgressState.None;

    lblProgresso.Visible := False;
    pbDownload.Visible := False;
  end);
end;

procedure TDownloadFTP_CaixaLocal.lvArquivosColumnClick(Sender: TObject;
  Column: TListColumn);
begin
  // Se clicou na mesma coluna que já estava ordenada, apenas inverte a direção
  if FSortColumn = Column.Index then
    FSortAscending := not FSortAscending
  else
  begin
    // Se clicou em uma coluna diferente, define ela como a nova coluna ativa
    FSortColumn := Column.Index;
    FSortAscending := True; // Começa sempre como crescente
  end;

  // Dispara o comando interno do Delphi para reordenar a lista
  // Isso vai chamar automaticamente o evento OnCompare que programaremos abaixo
  lvArquivos.AlphaSort;
  // ATUALIZA AS SETINHAS NO CABEÇALHO
  AtualizarSetasOrdenacao;
end;

procedure TDownloadFTP_CaixaLocal.lvArquivosCompare(Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer);
var
  TextoTamanho1, TextoTamanho2: string;
  NumTamanho1, NumTamanho2: Double;
  Data1, Data2: TDateTime;
begin
  // Trata a ordenação de acordo com a coluna selecionada (FSortColumn)
  case FSortColumn of

    // COLUNA 0: Nome do Arquivo (Texto Puro)
    0: begin
         Compare := AnsiCompareText(Item1.Caption, Item2.Caption);
       end;

    // COLUNA 1: Tamanho do Arquivo (Ex: "12,50 MB")
    1: begin
         // Remove o " MB" do final do texto para podermos converter em número real
         TextoTamanho1 := StringReplace(Item1.SubItems[0], ' MB', '', [rfIgnoreCase]);
         TextoTamanho2 := StringReplace(Item2.SubItems[0], ' MB', '', [rfIgnoreCase]);

         // Converte para Double de forma segura (se falhar, assume 0)
         NumTamanho1 := StrToFloatDef(TextoTamanho1, 0);
         NumTamanho2 := StrToFloatDef(TextoTamanho2, 0);

         // Faz a comparação numérica pura
         if NumTamanho1 < NumTamanho2 then Compare := -1
         else if NumTamanho1 > NumTamanho2 then Compare := 1
         else Compare := 0;
       end;

    // COLUNA 2: Data e Hora de Modificação (Ex: "25/06/2026 15:30:00")
    2: begin
         // Converte as strings guardadas de volta para o formato de Data/Hora do Delphi
         Data1 := StrToDateTimeDef(Item1.SubItems[1], 0);
         Data2 := StrToDateTimeDef(Item2.SubItems[1], 0);

         // Faz a comparação cronológica
         if Data1 < Data2 then Compare := -1
         else if Data1 > Data2 then Compare := 1
         else Compare := 0;
       end;
  end;

  // Se a nossa variável de controle disser que a ordem é decrescente,
  // nós simplesmente invertemos o resultado da comparação multiplicando por -1
  if not FSortAscending then
    Compare := -Compare;
end;

procedure TDownloadFTP_CaixaLocal.lvArquivosDblClick(Sender: TObject);
var
  NomeItem: string;
  i: Integer;
  ItemLista: TListItem;
begin
// BLOQUEIO: Se estiver baixando, ignora o duplo clique completamente!
  if FDownloadEmAndamento then Exit;
  // Se o usuário clicou em uma área vazia da lista, ignora
  if lvArquivos.Selected = nil then
    Exit;

  // Pega o nome do arquivo ou pasta selecionada (Coluna 0)
  NomeItem := lvArquivos.Selected.Caption;

  try
    // Verifica se o comando é para voltar uma pasta
    if NomeItem = '..' then
      IdFTP1.ChangeDirUp
    else if NomeItem = '.' then
      Exit // Pasta atual, não faz nada
    else
      IdFTP1.ChangeDir(NomeItem); // Tenta entrar na pasta selecionada

    // Se mudou de pasta com sucesso, solicita a nova lista de arquivos
    IdFTP1.List;

    // Atualiza o TListView com o conteúdo da nova pasta
    lvArquivos.Items.BeginUpdate;
    try
      lvArquivos.Items.Clear;
      for i := 0 to IdFTP1.DirectoryListing.Count - 1 do
      begin
        ItemLista := lvArquivos.Items.Add;
        ItemLista.Caption := IdFTP1.DirectoryListing[i].FileName;
// 1. ATUALIZAÇÃO: Exibe o tamanho em MB corretamente
        ItemLista.SubItems.Add(FormatFloat('#,##0.00 MB', IdFTP1.DirectoryListing[i].Size / 1048576));

        // 2. ATUALIZAÇÃO: Exibe a data no fuso local e remove os segundos
        ItemLista.SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', TTimeZone.Local.ToLocalTime(IdFTP1.DirectoryListing[i].ModifiedDate)));
      end;
    finally
      lvArquivos.Items.EndUpdate;
    end;

  except
    on E: Exception do
    begin
      // Se o comando ChangeDir falhar, o Indy avisa que não é um diretório.
      // Isso significa que o usuário deu duplo clique em um ARQUIVO.
      //ShowMessage('Você selecionou o arquivo: ' + NomeItem + #13#10 + 'Pronto para o download!');
    end;
  end;
end;

procedure TDownloadFTP_CaixaLocal.lvArquivosKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  Senha, NomeArquivo: string;
begin
  // Verifica se a tecla foi "Delete" e se o "Ctrl" estava pressionado junto
  if (Key = VK_DELETE) and (ssCtrl in Shift) then
  begin
    // Se não tem nada selecionado, ignora
    if lvArquivos.Selected = nil then Exit;

    NomeArquivo := lvArquivos.Selected.Caption;
    Senha := '';

    // O #31 é o segredo do Delphi para ocultar os caracteres no InputQuery!
      if InputQuery('Segurança', #31'Digite a senha para excluir:', Senha) then
    begin
      if Senha = SENHA_APP then
      begin
        // Senha correta! Dispara a exclusão em segundo plano para não travar a tela
        TThread.CreateAnonymousThread(procedure
        var
          ErroMsg: string;
        begin
          ErroMsg := '';

          // Mostra a tela de loading de novo para o usuário não mexer em nada
          TThread.Synchronize(nil, procedure begin
            FCarregando := True;
            pnlLoading.Visible := True;
            pnlLoading.BringToFront;
            edtSenha.Visible := False; // Garante que o campo de senha inicial não apareça agora
            btnConfirmarSenha.Visible := False;
          end);

          try
            // Exclui o arquivo físico no servidor FTP
            if not IdFTP1.Connected then IdFTP1.Connect;
            IdFTP1.Delete(NomeArquivo);
          except
            on E: Exception do ErroMsg := E.Message;
          end;

          // Sincroniza o resultado na tela
          TThread.Synchronize(nil, procedure begin
            if ErroMsg <> '' then
            begin
              ShowMessage('Erro ao excluir arquivo: ' + ErroMsg);
              pnlLoading.Visible := False;
              FCarregando := False;
            end
            else
            begin
              ShowMessage('Arquivo excluído com sucesso do servidor!');
              // Chama sua procedure que já atualiza a lista de arquivos
              AtualizarListaEmSegundoPlano;
            end;
          end);
        end).Start;
      end
      else
      begin
        ShowMessage('Senha incorreta! Exclusão cancelada.');
      end;
    end;
  end;
end;

procedure TDownloadFTP_CaixaLocal.lvArquivosSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  if FDownloadEmAndamento then Exit;
  // O botão de download só fica ativo se o FTP estiver conectado E se houver algum item selecionado na lista
  btnDownload.Enabled := IdFTP1.Connected and (lvArquivos.Selected <> nil);
end;

procedure TDownloadFTP_CaixaLocal.btnAbrirNoExplorerClick(Sender: TObject);
var
  CaminhoPasta: string;
  CaminhoArquivo: string;
  NomeArquivo: string;
begin
  // 1. Pega o caminho da pasta digitada no Edit
  CaminhoPasta := IncludeTrailingPathDelimiter(edtDestino.Text);

  // 2. Verifica se a pasta existe antes de tentar abrir
  if not DirectoryExists(CaminhoPasta) then
  begin
    ShowMessage('A pasta destino (' + CaminhoPasta + ') ainda não existe.');
    Exit;
  end;

  // 3. Tenta descobrir o nome do arquivo selecionado na lista
  if lvArquivos.Selected <> nil then
  begin
    NomeArquivo := lvArquivos.Selected.Caption;
    CaminhoArquivo := CaminhoPasta + NomeArquivo;

    // 4. Se o arquivo realmente existir lá na pasta do Windows...
    if FileExists(CaminhoArquivo) then
    begin
      // Comando mágico do Windows: Abre o Explorer, seleciona o arquivo e MAXIMIZA (SW_MAXIMIZE)
      ShellExecute(Handle, 'open', 'explorer.exe', PChar('/select,"' + CaminhoArquivo + '"'), nil, SW_MAXIMIZE);
      Exit; // Sai da procedure, pois já fez o trabalho
    end;
  end;

  // 5. CAIU AQUI? Significa que não tem arquivo selecionado OU o arquivo não foi baixado ainda.
  // Então apenas abre a pasta destino normalmente e MAXIMIZADA.
  ShellExecute(Handle, 'explore', PChar(CaminhoPasta), nil, nil, SW_MAXIMIZE);
end;

end.
