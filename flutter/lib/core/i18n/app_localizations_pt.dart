// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'DraconDex';

  @override
  String get nexusTitle => 'DraconDex';

  @override
  String get nexusSubtitle => 'Gerenciamento de Dados de Romances';

  @override
  String get moduleGlobalTags => 'Tags';

  @override
  String get moduleColors => 'Cores';

  @override
  String get moduleSettings => 'Configurações';

  @override
  String get btnNew => 'Novo';

  @override
  String get btnSave => 'Salvar';

  @override
  String get btnCancel => 'Cancelar';

  @override
  String get btnDelete => 'Excluir';

  @override
  String get btnEdit => 'Editar';

  @override
  String get btnClose => 'Fechar';

  @override
  String get btnAdd => 'Adicionar';

  @override
  String get btnImport => 'Importar BD';

  @override
  String get btnExport => 'Exportar BD';

  @override
  String get labelName => 'Nome';

  @override
  String get labelMemo => 'Memorando';

  @override
  String get labelColor => 'Cor';

  @override
  String get labelNote => 'Nota';

  @override
  String get labelTags => 'Tags';

  @override
  String get labelSearch => 'Buscar...';

  @override
  String get newHashtag => 'Nova Tag';

  @override
  String get noTags => 'Ainda não há tags.';

  @override
  String get noColors => 'Nenhuma cor na paleta.';

  @override
  String get noResults => 'Nenhum resultado encontrado.';

  @override
  String get confirmDeleteTitle => 'Confirmar Exclusão';

  @override
  String get confirmDeleteMessage => 'Esta ação não pode ser desfeita.';

  @override
  String get colorInUse => 'A cor está em uso e não pode ser excluída.';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeMidnight => 'Meia-noite';

  @override
  String get themeMoonlight => 'Luar';

  @override
  String get themeDaylight => 'Luz do Dia';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get uiScaleLabel => 'Escala da Interface';

  @override
  String get importSuccess => 'Banco de dados importado com sucesso.';

  @override
  String get importFailed => 'Falha na importação. Verifique o arquivo.';

  @override
  String get exportSuccess => 'Banco de dados exportado.';

  @override
  String get selectColor => 'Selecionar Cor';

  @override
  String get recentColors => 'Recentes';

  @override
  String get version => 'Versão 2.1.0';

  @override
  String get btnRename => 'Renomear';

  @override
  String get btnPin => 'Fixar';

  @override
  String get btnUnpin => 'Desafixar';

  @override
  String get newNexusTitle => 'Novo Nexus';

  @override
  String get renameNexusTitle => 'Renomear Nexus';

  @override
  String get newModuleTitle => 'Novo Módulo';

  @override
  String get renameModuleTitle => 'Renomear Módulo';

  @override
  String get newModuleTooltip => 'Novo Módulo';

  @override
  String get newNexusTooltip => 'Novo Nexus';

  @override
  String get emptyNexusMessage => 'Nenhum Nexus ainda. Toque em + para criar um.';

  @override
  String get emptyModuleMessage => 'Vazio. Toque em + para adicionar um módulo.';

  @override
  String get deleteNexusMessage => 'Isso exclui todos os módulos dentro dele. Esta ação não pode ser desfeita.';

  @override
  String get deleteModuleMessage => 'Isso também exclui todos os módulos aninhados dentro dele. Esta ação não pode ser desfeita.';

  @override
  String get labelKind => 'Tipo';

  @override
  String get kindContentUnavailable => 'Este tipo de módulo ainda não é totalmente compatível no celular — usando o campo de notas compartilhado abaixo.';

  @override
  String get notesHint => 'Notas para este módulo…';

  @override
  String get authorChapters => 'Capítulos';

  @override
  String get authorNewChapter => 'Novo capítulo';

  @override
  String get authorNoChapters => 'Ainda não há capítulos';

  @override
  String get authorContentHint => 'Escreva este capítulo…';

  @override
  String get scribeSessions => 'Sessões';

  @override
  String get scribeNewSession => 'Nova sessão';

  @override
  String get scribeNoSessions => 'Ainda não há sessões';

  @override
  String get scribeMessageHint => 'Escreva uma mensagem…';

  @override
  String get scribeSwitchSide => 'Trocar de lado';

  @override
  String get chroniclerEvents => 'Eventos';

  @override
  String get chroniclerNewEvent => 'Novo evento';

  @override
  String get chroniclerNoEvents => 'Ainda não há eventos';

  @override
  String get chroniclerUntitledEvent => 'Evento sem título';

  @override
  String get chroniclerStart => 'Início';

  @override
  String get chroniclerYear => 'Ano';

  @override
  String get chroniclerMonth => 'Mês';

  @override
  String get chroniclerDay => 'Dia';

  @override
  String get chroniclerHour => 'Hora';

  @override
  String get chroniclerMinute => 'Minuto';

  @override
  String get chroniclerHasEnd => 'Tem data de fim';

  @override
  String get chroniclerStory => 'História';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsData => 'Dados';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get exportDbTitle => 'Exportar Banco de Dados';

  @override
  String get exportDbSubtitle => 'Compartilhe o arquivo .db para transferir dados para um PC ou outro dispositivo';

  @override
  String get importDbTitle => 'Importar Banco de Dados';

  @override
  String get importDbSubtitle => 'Mesclar dados de um arquivo .db do DraconDex';

  @override
  String get checkUpdatesTitle => 'Verificar Atualizações';

  @override
  String get checkUpdatesSubtitle => 'Consulta os GitHub Releases deste projeto — sempre pergunta antes de instalar';

  @override
  String get upToDateMessage => 'Você já está na versão mais recente.';

  @override
  String get importingMessage => 'Importando…';

  @override
  String get importCompleteMessage => 'Importação concluída.';

  @override
  String get importFailedMessage => 'Falha na importação.';

  @override
  String get exportFailedMessage => 'Falha na exportação.';

  @override
  String get saveFailedMessage => 'Falha ao salvar.';

  @override
  String get webBackupUnsupportedMessage => 'Não disponível na versão web.';

  @override
  String get driveBackupTitle => 'Backup no Google Drive';

  @override
  String get driveConnectedAs => 'Conectado:';

  @override
  String get driveNotConnected => 'Não conectado';

  @override
  String get driveConnect => 'Conectar';

  @override
  String get driveDisconnect => 'Desconectar';

  @override
  String get driveBackupNow => 'Fazer backup agora';

  @override
  String get driveRestoreTitle => 'Restaurar do Google Drive';

  @override
  String get driveRestoreSubtitle => 'Mescla o backup do Drive com seus dados atuais';

  @override
  String get driveConnectFailedMessage => 'Falha na conexão.';

  @override
  String get driveBackingUpMessage => 'Fazendo backup no Google Drive…';

  @override
  String get driveBackupSuccessMessage => 'Backup concluído.';

  @override
  String get driveBackupFailedMessage => 'Falha no backup.';

  @override
  String get addColorTitle => 'Adicionar Cor';

  @override
  String get colorPaletteTitle => 'Paleta de Cores';

  @override
  String get hashtagsTitle => 'Tags';

  @override
  String get editHashtagTitle => 'Editar Tag';

  @override
  String get tagNameLabel => 'Nome da Tag';

  @override
  String get removeColorConfirmTitle => 'Remover cor?';

  @override
  String get deleteHashtagConfirmTitle => 'Excluir tag?';

  @override
  String get builderNavHome => 'Início';

  @override
  String get builderNavView => 'Visualização';

  @override
  String get builderNavFolders => 'Visualizações de pasta';

  @override
  String get viewModeTitle => 'Modo de visualização';

  @override
  String get viewModeList => 'Lista';

  @override
  String get viewModeGrid => 'Grade';

  @override
  String get viewModeCompact => 'Compacta';

  @override
  String get recentViewsTitle => 'Visualizações recentes';

  @override
  String get recentViewsEmpty => 'Ainda não há visualizações recentes';

  @override
  String get recentViewsClear => 'Limpar tudo';

  @override
  String get builderNexusRootLabel => 'Raiz do Nexus';

  // --- Supabase project setup (features/settings/supabase_setup_screen.dart) ---

  @override
  String get settingPageSupabase => 'Projeto do Supabase';

  @override
  String get sbIntro => 'Use o seu próprio projeto do Supabase como servidor do Cloud Sync. Cole a URL do projeto e a chave publishable, e deixe o DraconDex verificar e instalar as tabelas necessárias.';

  @override
  String get sbUrl => 'URL do projeto';

  @override
  String get sbKey => 'Chave publishable';

  @override
  String get sbKeyStored => 'Já existe uma chave salva — deixe vazio para mantê-la.';

  @override
  String get sbCheck => 'Verificar projeto';

  @override
  String get sbObjects => 'Tabelas e funções necessárias';

  @override
  String get sbSchemaVersion => 'Versão do schema';

  @override
  String get sbReady => 'Pronto — este projeto tem tudo o que o Cloud Sync precisa.';

  @override
  String get sbNeedSetup => 'Falta instalar — algumas tabelas ou funções não existem.';

  @override
  String get sbNotChecked => 'Ainda não verificado. Salve as configurações acima e toque em "Verificar projeto".';

  @override
  String get sbAutoInstall => 'Instalação automática';

  @override
  String get sbAutoInstallHint => 'Uma chave publishable não cria tabelas. Cole um token de acesso pessoal do Supabase e o DraconDex executa o SQL de instalação por você.';

  @override
  String get sbAccessToken => 'Token de acesso pessoal';

  @override
  String get sbAccessTokenHint => 'Usado só nesta requisição — nunca é salvo.';

  @override
  String get sbGetToken => 'Obter um token';

  @override
  String get sbManualTitle => 'Ou instale manualmente';

  @override
  String get sbManualHint => 'Copie o SQL, execute no editor SQL do seu projeto e toque em "Verificar projeto" novamente.';

  @override
  String get sbCopySql => 'Copiar SQL';

  @override
  String get sbOpenSqlEditor => 'Abrir editor SQL';

  @override
  String get sbOpenApiSettings => 'Abrir configurações de API';

  @override
  String get sbOpenAuthProviders => 'Abrir provedores de Auth';

  @override
  String get sbGoogleOn => 'O login com Google está ativado neste projeto.';

  @override
  String get sbGoogleOff => 'O login com Google está desativado — ative em Authentication → Providers antes de entrar.';

  @override
  String get sbInstalled => 'Instalação concluída';

  @override
  String get sbClear => 'Remover projeto';

  @override
  String get sbClearConfirm => 'Remover as configurações salvas do projeto do Supabase?';

  @override
  String get sbCleared => 'Configurações do Supabase removidas';

  @override
  String get sbErrNoConfig => 'Informe primeiro a URL do projeto e a chave publishable.';

  @override
  String get sbErrInvalidUrl => 'Essa URL de projeto não é válida — somente https.';

  @override
  String get sbErrBadKey => 'O projeto rejeitou esta chave.';

  @override
  String get sbErrUnreachable => 'Não foi possível alcançar esse projeto.';

  @override
  String get sbErrNeedsManual => 'Sem token de acesso — use os passos manuais.';

  @override
  String get sbErrBadAccessToken => 'Esse token de acesso foi rejeitado.';

  @override
  String get sbErrForbidden => 'Este token não tem permissão para alterar esse projeto.';

  @override
  String get sbErrNoProjectRef => 'A instalação automática precisa de uma URL de projeto supabase.co.';

  @override
  String get sbErrRateLimited => 'Requisições demais — tente de novo daqui a pouco.';

  @override
  String get sbErrSqlError => 'Falha ao executar o SQL de instalação.';

  @override
  String get sbErrNetwork => 'Erro de rede — não foi possível alcançar o projeto.';

  @override
  String get sbCopied => 'Copiado';

  @override
  String get sbNotConfigured => 'Nenhum projeto configurado ainda';
  @override
  String get googleAccountTitle => 'Conta do Google';

  @override
  String get googleAccountNotConfigured => 'Nenhum cliente OAuth configurado ainda';

  @override
  String get googleAccountSetupTitle => 'Configuração do login do Google';

  @override
  String get googleClientTypeHintNative => 'No Google Cloud Console, ative a API do Google Drive e crie um cliente OAuth do tipo "App para computador"; depois cole os dados abaixo.';

  @override
  String get googleClientTypeHintWeb => 'No Google Cloud Console, ative a API do Google Drive e crie um cliente OAuth do tipo "Aplicativo da Web"; depois cole o ID do cliente abaixo.';

  @override
  String get googleClientIdLabel => 'ID do cliente';

  @override
  String get googleClientSecretLabel => 'Chave secreta do cliente';

  @override
  String get googleClientSecretKept => 'Já há uma chave secreta salva. Deixe em branco para mantê-la.';

  @override
  String get googleRedirectUriLabel => 'URI de redirecionamento autorizado';

  @override
  String get googleRedirectUriHint => 'Adicione este endereço exato aos URIs de redirecionamento autorizados do cliente e o endereço deste site às origens JavaScript autorizadas.';

  @override
  String get googleSessionExpired => 'A sessão expirou — conecte novamente';

  @override
  String get googleErrNoConfig => 'Informe primeiro os dados do cliente OAuth.';

  @override
  String get googleErrCancelled => 'O login foi cancelado.';

  @override
  String get googleErrTimeout => 'O tempo do login esgotou.';

  @override
  String get googleErrVerify => 'Não foi possível verificar o login. Tente novamente.';

  @override
  String get googleErrNetwork => 'Não foi possível acessar o Google.';

  @override
  String get googleErrAuth => 'O Google recusou o login.';

  @override
  String get googleErrPopupBlocked => 'A janela de login foi bloqueada. Permita pop-ups neste site e tente novamente.';

  @override
  String get googleErrNotConnected => 'Nenhuma conta do Google conectada.';

  @override
  String get driveRestoreSettingsTitle => 'Restaurar configurações do Drive';

  @override
  String get driveRestoreSettingsSubtitle => 'Substitui tema, idioma e tamanho da interface pelos do backup.';

  @override
  String get driveSettingsRestoredMessage => 'Configurações restauradas do Google Drive.';

  @override
  String get driveNoBackupMessage => 'Nenhum backup encontrado no Google Drive.';

  @override
  String get driveWebDatabaseNote => 'Na versão de navegador só as configurações são salvas — o banco de dados fica neste dispositivo.';

  @override
  String get hubNestTitle => 'Ninho Nexus';

  @override
  String get hubPanelShow => 'Mostrar o painel do hub';

  @override
  String get hubPanelHide => 'Ocultar o painel do hub';

  @override
  String get railExpand => 'Expandir a barra';

  @override
  String get railCollapse => 'Recolher a barra';

  // --- DDX Transfer ---

  @override
  String get transferTitle => 'Transferir';

  @override
  String get transferSubtitle => 'Entregue um Nexus inteiro a outro dispositivo. Sem conta e sem configuração — quem envia mostra um código, quem recebe digita, e a cópia intermediária é apagada assim que chega.';

  @override
  String get transferTabSend => 'Enviar';

  @override
  String get transferTabReceive => 'Receber';

  @override
  String get transferNexusLabel => 'Nexus';

  @override
  String get transferPickNexus => 'Abra o Nexus que quer enviar.';

  @override
  String get transferAllowTyped => 'Permitir receber digitando o código';

  @override
  String get transferAllowTypedHint => 'Ligado, o outro dispositivo pode digitar o código e o PIN, em troca de o serviço guardar a chave selada com esse PIN enquanto espera. Desligado, o QR é a única entrada e o serviço não consegue ler o arquivo de forma alguma.';

  @override
  String get transferCreate => 'Criar transferência';

  @override
  String get transferCode => 'Código de transferência';

  @override
  String get transferPin => 'PIN';

  @override
  String get transferCopyLink => 'Copiar link';

  @override
  String get transferModeTyped => 'Escaneie o QR, ou digite o código e o PIN. Enquanto espera, o serviço guarda a chave selada com o PIN.';

  @override
  String get transferModeQr => 'Somente QR. A chave nunca chega ao serviço, então ninguém além do dispositivo que escaneia consegue abrir isto.';

  @override
  String get transferExpiry => 'Expira em 30 minutos, e é apagada assim que for recebida.';

  @override
  String get transferWaiting => 'Aguardando o outro dispositivo…';

  @override
  String get transferClaimed => 'O outro dispositivo verificou o código e está baixando…';

  @override
  String get transferDone => 'Recebido. A cópia no serviço foi apagada.';

  @override
  String get transferExpiredNotice => 'Expirou antes de alguém receber.';

  @override
  String get transferVerify => 'Verificar';

  @override
  String get transferFound => 'Transferência encontrada';

  @override
  String get transferProject => 'Nexus';

  @override
  String get transferSize => 'Tamanho';

  @override
  String get transferCreated => 'Criado';

  @override
  String get transferSource => 'Enviado de';

  @override
  String get transferReceiveAsNew => 'Chega como um Nexus novo. Nada do que você já tem é tocado.';

  @override
  String get transferReceiveAction => 'Receber';

  @override
  String get transferReceived => 'Nexus recebido';

  @override
  String get transferErrNetwork => 'Não foi possível contatar o serviço de transferência.';

  @override
  String get transferErrBadCode => 'Esse código de transferência ou PIN não está certo.';

  @override
  String get transferErrLocked => 'PIN errado vezes demais. Esta transferência fica bloqueada por um tempo.';

  @override
  String get transferErrExpired => 'Esta transferência expirou. Peça um código novo.';

  @override
  String get transferErrGone => 'Esta transferência não existe mais — foi recebida ou cancelada.';

  @override
  String get transferErrNotReady => 'O outro dispositivo ainda não terminou de enviar.';

  @override
  String get transferErrTooLarge => 'Este Nexus é maior do que uma transferência permite.';

  @override
  String get transferErrBadToken => 'Esta sessão de transferência não vale mais. Comece de novo.';

  @override
  String get transferErrBadKey => 'Esse link está incompleto — falta a parte da chave ou ela está danificada.';

  @override
  String get transferErrQrOnly => 'Quem enviou permitiu apenas o QR. Escaneie em vez de digitar.';

  @override
  String get transferErrBadPayload => 'Não foi possível ler o arquivo recebido.';

  @override
  String get transferErrServer => 'O serviço de transferência teve um problema.';

  @override
  String get transferSending => 'Enviando…';

  @override
  String get transferCopied => 'Link copiado';

  @override
  String get transferCancel => 'Cancelar';

  @override
  String get transferPasteLink => 'Ou cole um link de transferência';

  @override
  String get transferPasteLinkHint => 'O link leva a chave dentro dele, então funciona mesmo se quem enviou permitiu apenas o QR.';
}
