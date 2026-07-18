unit UnitAtu;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls;

type
  TFormAtu = class(TForm)
    Label1: TLabel;
    SpeedButton1: TSpeedButton;
    LogAtu: TRichEdit;
    procedure SpeedButton1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormAtu: TFormAtu;

implementation

{$R *.dfm}

procedure TFormAtu.SpeedButton1Click(Sender: TObject);
begin
  Close;
end;

end.
