unit uNetInterfaces;

// Enumerate IPv4 broadcast addresses (multi-NIC / VPN; KortexUpdate-style).

interface

uses
 System.SysUtils,
 System.Classes;

function EnumBroadcastAddresses: TArray<string>;

implementation

{$IFDEF MSWINDOWS}
uses
 Winapi.Windows,
 Winapi.Winsock,
 Common;

const
 SIO_GET_INTERFACE_LIST = $4004747F;
 MAX_INTERFACE_INFO     = 128;

type
 SockAddrGen = packed record
 public
  AddressIn: sockaddr_in;
  filler:    packed array [0 .. 7] of AnsiChar;
 end;

 INTERFACE_INFO = packed record
 public
  iiFlags:            u_long;
  iiAddress:          SockAddrGen;
  iiBroadcastAddress: SockAddrGen;
  iiNetmask:          SockAddrGen;
 end;

function WSAIoctl(s: TSocket; cmd: DWORD; lpInBuffer: Pointer; dwInBufferLen: DWORD; lpOutBuffer: Pointer; dwOutBufferLen: DWORD;
 lpdwOutBytesReturned: LPDWORD; lpOverLapped: Pointer; lpOverLappedRoutine: Pointer): Integer; stdcall; external 'WS2_32.DLL' name 'WSAIoctl';
{$ENDIF}

{$IFDEF POSIX}
uses
 Posix.Base,
 Posix.SysSocket,
 Posix.NetinetIn,
 Posix.ArpaInet;

const
 IFF_UP        = $1;
 IFF_BROADCAST = $2;
 IFF_LOOPBACK  = $8;

type
 Pifaddrs = ^ifaddrs;
 ifaddrs = record
  ifa_next:    Pifaddrs;
  ifa_name:    MarshaledAString;
  ifa_flags:   Cardinal;
  ifa_addr:    Psockaddr;
  ifa_netmask: Psockaddr;
  ifa_ifu:     record
   case Integer of
    0: (ifu_broadaddr: Psockaddr);
    1: (ifu_dstaddr:   Psockaddr);
  end;
  ifa_data: Pointer;
 end;

function getifaddrs(var ifap: Pifaddrs): Integer; cdecl; external libc name _PU + 'getifaddrs';
procedure freeifaddrs(ifap: Pifaddrs); cdecl; external libc name _PU + 'freeifaddrs';
{$ENDIF}

function EnumBroadcastAddresses: TArray<string>;
 var
  List: TStringList;
{$IFDEF MSWINDOWS}
  sock:          TSocket;
  wsaD:          WSADATA;
  NumInterfaces: Integer;
  BytesReturned: u_long;
  Buffer:        array [0 .. MAX_INTERFACE_INFO - 1] of INTERFACE_INFO;
  i:             Integer;
  ip, mask, broadcast: TInAddr;
  ipS, broadcastS: string;
{$ENDIF}
{$IFDEF POSIX}
  IfAddrsList: Pifaddrs;
  Ifa:         Pifaddrs;
  BroadSa:     Psockaddr;
  ip, mask, broadcast: in_addr;
  ipS, broadcastS: string;
{$ENDIF}

 begin
  List := TStringList.Create;
  try
   List.Sorted := TRUE;
   List.Duplicates := dupIgnore;

{$IFDEF MSWINDOWS}
   FillChar(wsaD, SizeOf(wsaD), 0);

   if WSAStartup($0101, wsaD) = 0 then
    try
     sock := Socket(AF_INET, SOCK_STREAM, 0);

     if sock <> INVALID_SOCKET then
      try
       BytesReturned := 0;

       if WSAIoctl(sock, SIO_GET_INTERFACE_LIST, nil, 0, @Buffer, SizeOf(Buffer), @BytesReturned, nil, nil) <> SOCKET_ERROR then
        begin
         NumInterfaces := Integer(BytesReturned) div SizeOf(INTERFACE_INFO);

         for i := 0 to NumInterfaces - 1 do
          begin
           ip := Buffer[i].iiAddress.AddressIn.sin_addr;
           mask := Buffer[i].iiNetmask.AddressIn.sin_addr;
           broadcast.S_addr := ip.S_addr or (not mask.S_addr);

           ipS := string(AnsiString(inet_ntoa(ip)));
           broadcastS := string(AnsiString(inet_ntoa(broadcast)));

           if (ipS <> '') and (ipS <> '127.0.0.1') and (broadcastS <> '') and (broadcastS <> '0.0.0.0') then
            List.Add(broadcastS);
          end;
        end
       else
        DebugLogSilentExcept('EnumBroadcastAddresses.WSAIoctl', IntToStr(WSAGetLastError));
      finally
       CloseSocket(sock);
      end;
    finally
     WSACleanup;
    end;
{$ENDIF}

{$IFDEF POSIX}
   IfAddrsList := nil;

   if getifaddrs(IfAddrsList) = 0 then
    try
     Ifa := IfAddrsList;

     while Ifa <> nil do
      begin
       if (Ifa.ifa_addr <> nil) and (Ifa.ifa_addr.sa_family = AF_INET) and
          ((Ifa.ifa_flags and IFF_UP) <> 0) and
          ((Ifa.ifa_flags and IFF_BROADCAST) <> 0) and
          ((Ifa.ifa_flags and IFF_LOOPBACK) = 0) then
        begin
         ip := Psockaddr_in(Ifa.ifa_addr)^.sin_addr;
         ipS := string(AnsiString(inet_ntoa(ip)));

         BroadSa := Ifa.ifa_ifu.ifu_broadaddr;

         if BroadSa <> nil then
          broadcast := Psockaddr_in(BroadSa)^.sin_addr
         else if Ifa.ifa_netmask <> nil then
          begin
           mask := Psockaddr_in(Ifa.ifa_netmask)^.sin_addr;
           broadcast.s_addr := ip.s_addr or (not mask.s_addr);
          end
         else
          broadcast.s_addr := 0;

         broadcastS := string(AnsiString(inet_ntoa(broadcast)));

         if (ipS <> '') and (ipS <> '127.0.0.1') and (broadcastS <> '') and (broadcastS <> '0.0.0.0') then
          List.Add(broadcastS);
        end;

       Ifa := Ifa.ifa_next;
      end;
    finally
     freeifaddrs(IfAddrsList);
    end;
{$ENDIF}

   List.Add('255.255.255.255');

   SetLength(Result, List.Count);
   for var n := 0 to List.Count - 1 do
    Result[n] := List[n];
  finally
   List.Free;
  end;
 end;

end.
