#!/usr/bin/perl -wT -I/home/pearlshed/cgi-bin/lib

use strict;
use CGI qw/:param/;
use Mail::POP3Client;
use MIME::Parser;
use MIME::QuotedPrint;
use MIME::Base64;
use Net::SMTP;
use Time::Local;
use utf8;

$ENV{'PATH'} = '';
my $sendmailExec = '/usr/bin/mail';
my $selfName = 'WebMail.pl';
my $stylesheetURL = "$selfName?action=PrintStylesheet";
my $SMTPServerName = 'mail.pearlshed.nl';
my $cgi = new CGI;

sub JavascriptEncodeText($)
{
  my $string = shift;
  unless (defined ($string))
  {
    $string = '';
  }
  $string =~ s/\&/&amp;/cg;
  $string =~ s/>/&gt;/cg;
  $string =~ s/</&lt;/cg;
  $string =~ s/\"/&quot;/cg;
  $string =~ s/\'/\\'/cg;
  $string =~ s/\`/\\'/cg;
  $string =~ s/\r\n/<br>/g;
  $string =~ s/\r/<br>/g;
  $string =~ s/\n/<br>/g;
  $string =~ s/([\x{80}-\x{ffff}])/sprintf('&#x%04X;', ord($1))/ge;
  return "$string";
}

sub JavascriptEncodeHTML($)
{
  my $string = shift;
  unless (defined ($string))
  {
    $string = '';
  }
  $string =~ s/'/\\'/g;
  $string =~ s/\r/\\r/g;
  $string =~ s/\n/\\n/g;
  return $string;
}

sub PrintFrameset()
{
  print "Content-type: text/html\n\n";
  print <<"  EOF";
<html>
<head>
<title>WebMail</title>
</head>
<frameset rows="22,*" frameborder="no">
<frame name="top" src="$selfName?action=PrintToolbar" noresize>
<frameset rows="230,*" frameborder="no">
<frame name="middle">
<frame name="bottom" frameborder="yes">
</frameset>
</html>
  EOF
}

sub PrintSendMessageForm()
{
  print "Content-type: text/html\n\n";
  print <<"  EOF";
<html>
<head>
<title>Create New Mail - WebMail</title>
<link rel="stylesheet" href="$stylesheetURL">
</head>
<body onLoad="sendmail.to.focus();">
<form name="sendmail" action="$selfName" method="post">
<table width="100%" height="100%">
<input type="hidden" name="action" value="SendMail">
<tr><td width="60" height="1">To <input type="submit" value="send"></td><td><input type="text" name="to" id="test1" style="width:100%;"></td></tr>
<!--
<tr><td width="60" height="1">Cc</td><td><input type="text" name="cc" style="width:100%;"></td></tr>
<tr><td width="60" height="1">Bcc</td><td><input type="text" name="bcc" style="width:100%;"></td></tr>
-->
<tr><td width="60" height="1">Subject</td><td><input type="text" name="subject" style="width:100%;"></td></tr>
<tr><td colspan="2"><textarea name="content" style="width:100%; height:100%;"></textarea></td></tr>
</table>
</form>
</body>
</html>
  EOF
}

sub PrintToolbar()
{
  print "Content-type: text/html\n\n";
  print <<"  EOF";
<html>
<head>
<title>WebMail</title>
<link rel="stylesheet" href="$stylesheetURL">
<script>
var i = 0;
function CreateNewMail(action)
{
  i++;
  var to = "";
  var subject = "";
  var body = "";
  if ((typeof parent.middle.HighLightedRowObject == 'object') && (parent.middle.HighLightedRowObject != -1))
  {
    if ((action == "reply") || (action == "forward"))
    {
      subject = "Re: " + parent.middle.HighLightedRowObject.childNodes[2].innerText;
      body = parent.bottom.document.body.innerText;
    }
    if (action == "reply")
    {
      to = parent.middle.HighLightedRowObject.childNodes[1].innerText;
    }
  }
  myWindow = window.open("", "SendWindow" + i, 'resizable,width=600,height=400');
  myWindow.document.open();
  myWindow.document.write ('<html>\\n<head>\\n<title>Create New Mail - WebMail</title>\\n');
  myWindow.document.write ('<link rel="stylesheet" href="$stylesheetURL">\\n</head>\\n<body>\\n');
  myWindow.document.write ('<form name="sendmail" action="$selfName" method="post">\\n<table width="100%" height="100%">\\n');
  myWindow.document.write ('<input type="hidden" name="action" value="SendMail">\\n');
  myWindow.document.write ('<tr><td width="60" height="1">To <input type="submit" value="send"></td><td><input type="text" name="to" style="width:100%;" value="' + to + '"></td></tr>\\n');
  //<tr><td width="60" height="1">Cc</td><td><input type="text" name="cc" style="width:100%;"></td></tr>
  //<tr><td width="60" height="1">Bcc</td><td><input type="text" name="bcc" style="width:100%;"></td></tr>
  myWindow.document.write ('<tr><td width="60" height="1">Subject</td><td><input type="text" name="subject" style="width:100%;" value="' + subject + '"></td></tr>\\n');
  myWindow.document.write ('<tr><td colspan="2"><textarea name="content" style="width:100%; height:100%;">' + body.replace(/\\n/g,'\\n> ') + '</textarea></td></tr>\\n');
  myWindow.document.write ('</table>\\n</form>\\n</body>\\n</html>');
}

function GetCookie(name)
{
  var start = document.cookie.indexOf(name+"=");
  var len = start+name.length+1;
  if ((!start) && (name != document.cookie.substring(0,name.length))) return null;
  if (start == -1) return '';
  var end = document.cookie.indexOf(";",len);
  if (end == -1) end = document.cookie.length;
  return unescape(document.cookie.substring(len,end));
}

function SetCookie(name,value,expires,path,domain,secure)
{
  document.cookie = name + "=" +escape(value) + ((expires) ? ";expires=" + expires.toGMTString() : "") +
  ((path) ? ";path=" + path : "") + ((domain) ? ";domain=" + domain : "") + ((secure) ? ";secure" : "");
}
function FillAndFocus()
{
  document.loginForm.servername.value = GetCookie('servername');
  document.loginForm.username.value = GetCookie('username');
  if (document.loginForm.servername.value == "")
  {
    document.loginForm.servername.focus();
  }
  else
  {
    document.loginForm.password.focus();
  }
}
function SubmitForm()
{
  var today = new Date();
  var expires = new Date(today.getTime() + (365 * 86400000));
  SetCookie('servername', document.loginForm.servername.value, expires);
  SetCookie('username', document.loginForm.username.value, expires);
  return true;
}
</script>
</head>
<body onLoad="FillAndFocus();">
<form name="loginForm" action="$selfName" target="middle" method="post" onSubmit="return SubmitForm();">
<input type="hidden" name="action" value="PrintList">
provider
<select name="mailserver" onChange="this.form.servername.value = this.options[this.selectedIndex].value;">
<option></option>
<option value="pop3.12move.nl">12move</option>
<option value="pop3.24hoursnet.nl">24hoursnet</option>
<option value="mail.a2000.nl">A2000(UPC)</option>
<option value="pop.ae.nl">AE Internet</option>
<option value="pop.bart.nl">bART</option>
<option value="pop.betternet.nl">Betternet</option>
<option value="mail.flakkee.net">Betuwe.net</option>
<option value="smtp.cable4u.nl">Cable4u</option>
<option value="pop3.cameonline.nl">Cameonline</option>
<option value="pop3.capitolonline.nl">Capitolonline</option>
<option value="pop.control.nl">Cartel</option>
<option value="pop.casema.net">Casema</option>
<option value="pop.castel.nl">Castel</option>
<option value="mail.chello.nl">Chello</option>
<option value="pop3.cistron.nl">Cistron</option>
<option value="pop3.mbit.nl">Cistron(ADSL-mbit)</option>
<option value="pop3.cobweb.nl">Cobweb</option>
<option value="pop.compaqnet.nl">Compaqnet</option>
<option value="imap.cs.com">CompuServe 2000</option>
<option value="pop.compuserve.com">CompuServe Classic</option>
<option value="mail.concepts.nl">Concepts</option>
<option value="pop.worldonline.nl">Consunet</option>
<option value="pop3.csnet.nl">Csnet</option>
<option value="mail.cybercomm.nl">Cybercomm</option>
<option value="pop.dataweb.nl">Dataweb</option>
<option value="mail.daxis.nl">Daxis</option>
<option value="mail.ddsgouda.nl">DDSGouda</option>
<option value="pop.denhaag.org">De Digitale Hofstad</option>
<option value="pop.dds.nl">De Digitale Stad (DDS)</option>
<option value="mail.ddsw.nl">De Digitale Stad Wageningen</option>
<option value="delftnet.nl">Delftnet</option>
<option value="pop3.demon.nl">Demon</option>
<option value="ns.dialog.nl">Dialog</option>
<option value="mail.digitalemotions.com">Digital Emotions</option>
<option value="mail.ijmond.nl">Digitale Regio IJmond</option>
<option value="www.dsdelft.nl">Digitale stad Delft</option>
<option value="pop.dse.nl">Digitale stad Eindhoven</option>
<option value="mail.enschede.com">Digitale stad Enschede</option>
<option value="mailhost.dsv.nl">Digitale Stad Vlaardingen etc.</option>
<option value="mail.diza.nl">Digitale Zaanstad</option>
<option value="mail.direct5.net">Direct5</option>
<option value="mail.dutch.nl">Dutch Info Center.nl</option>
<option value="pop3.dutchnet.nl">Dutchnet</option>
<option value="pop3.dutchweb.net">Dutchweb(1)</option>
<option value="mail.dutchweb.net">Dutchweb(2)</option>
<option value="smtp1.etrade.nl">E.trade(1)</option>
<option value="mail.devries.etrade.nl">E.trade(2)</option>
<option value="62.100.30.37">E.trade(3)</option>
<option value="lupine.nl.easynet.net">Easynet</option>
<option value="pop3.enternet.nl">Enternet</option>
<option value="pop.keyaccess.nl">Essent KabelCom (keyaccess)</option>
<option value="pop.euronet.nl">Euronet</option>
<option value="pop2.euronet.nl">Euronet(pop2)</option>
<option value="pop.euroxs.net">Euroxs</option>
<option value="pop3.filternet.nl">Filternet</option>
<option value="pop.flevonet.nl">FlevoNet</option>
<option value="mail.flexvalue.nl">Flexvalue</option>
<option value="pop3.freeler.nl">Freeler</option>
<option value="pop3.gironet.nl">Gironet</option>
<option value="pop3.globalxs.nl">Globalxs</option>
<option value="pop3.globe.nl">Globe</option>
<option value="mail.goldmine.nl">Goldmine</option>
<option value="pop.hccnet.nl">Hccnet</option>
<option value="pop.hetnet.nl">Het Net</option>
<option value="mail.home.nl">Home</option>
<option value="pop.iaehv.nl">Internet Access Eindhoven ofwel:</option>
<option value="pop.iaehv.nl">Internet Access for Everyone</option>
<option value="mail.highway.nl">Internet Highway</option>
<option value="fs1.ilimburg.nl">Internet Limburg</option>
<option value="pop3.inn.nl">InterNetNoord</option>
<option value="pop.interstroom.nl">Interstroom</option>
<option value="mail.intouch.net">Intouch</option>
<option value="pop3.introweb.nl">Introweb</option>
<option value="mail.ixs.nl">IXS (Internet Acces Nederland)</option>
<option value="pop.kabelfoon.nl">Kabelfoon (1)(Kabelfoon.nl)</option>
<option value="borg.kabelfoon.nl">Kabelfoon(2)(Kabelfoon.nl)</option>
<option value="mailserv.caiw.nl">Kabelfoon(Caiw)</option>
<option value="pop.kennisnet.nl">Kennisnet</option>
<option value="pop.keyaccess.nl">Keyaccess</option>
<option value="pop.knot.nl">Knot</option>
<option value="pop.knoware.nl">Knoware</option>
<option value="mail.mac.com">Mac.com</option>
<option value="62.100.30.36">Myweb(1)</option>
<option value="62.100.30.37">Myweb(2)</option>
<option value="mint.nl.gxn.net">Myweb(3)</option>
<option value="pop.nederland.net">Nederland.net</option>
<option value="mail.nedernet.nl">Nedernet</option>
<option value="pop.noknok.nl">Noknok</option>
<option value="mail.westbrabant.net">NoordBrabantNet</option>
<option value="mail.onetelnet.nl">Onetelnet</option>
<option value="relay1.worldonline.nl">OpenNet</option>
<option value="pop.pine.nl">Pine</option>
<option value="pop.planet.nl">Planet Internet(planet.nl)</option>
<option value="pop.wxs.nl">Planet Internet(wxs.nl)</option>
<option value="mail.plant.nl">Plant</option>
<option value="rabbit.plaza.nl">Plaza</option>
<option value="pophost.plex.nl">Plex</option>
<option value="mail.prioritytelecom.com">Priority Telecom</option>
<option value="pop.prioserve.net">Prioserve</option>
<option value="pop3.qsnl.com">Qsnl</option>
<option value="pop.quicknet.nl">QuickNet(1)</option>
<option value="mx01.quicknet.nl">Quicknet(2)</option>
<option value="pop3.raketnet.nl">Raketnet</option>
<option value="mail.rapnet.nl">Rapnet</option>
<option value="remsv001.remotion.nl">Remotion</option>
<option value="mxhost.safekidszone.nl">Safekidszone</option>
<option value="pop3.scarlet.nl">Scarlet</option>
<option value="mail.scoutnet.nl">Scoutnet</option>
<option value="selamas.nl">SelaMas</option>
<option value="mailhost.snel.net">Snel.net</option>
<option value="pop.softhome.net">Softhome</option>
<option value="pop.solcon.nl">Solcon</option>
<option value="soneramail.nl">Sonera Internet</option>
<option value="pop.sonera-xs.nl">Sonera XS</option>
<option value="bbs.spidernet.nl">Spidernet</option>
<option value="mail.stads.net">Stadsnet</option>
<option value="mail.stannet.nl">Stannet</option>
<option value="mail.sdrn.nl">Stichting Digitale Regio Noordkop</option>
<option value="pop3.conceptsfa.nl">Studenten.net</option>
<option value="mail.subhosting.nl">Subhosting</option>
<option value="mail.support.nl">Support Net</option>
<option value="pop3.systemec.nl">Systemec</option>
<option value="mail.talkline.nl">Talkline</option>
<option value="mail.tebenet.nl">Tebenet</option>
<option value="alfa.tele2.nl:109">Tele2</option>
<option value="pop.telebyte.nl">Telebyte</option>
<option value="pop.telekabel.nl">Telekabel</option>
<option value="quicknet.nl">Telekabel(quicknet)</option>
<option value="arnhem.telekabel.nl">Telekabel2.nl</option>
<option value="mail.terschelling.net">Terschelling.net</option>
<option value="pop.thuis.nl">Thuis.nl</option>
<option value="pop3.tip.nl">Tip (The Internet Plaza)</option>
<option value="pop3.tiscali.nl">Tiscali</option>
<option value="mail.eikel.tmfweb.nl">TMFweb(1)</option>
<option value="mail.groot.tmfweb.nl">TMFweb(2)</option>
<option value="pop3.tomaatnet.nl">Tomaatnet</option>
<option value="pop3.tref.nl">Trefpunt Access</option>
<option value="mail.tritone-tele.com">Tritone-tele</option>
<option value="pop.trouwweb.nl">Trouwweb</option>
<option value="mail.twente.nl">Twente Digitaal</option>
<option value="mail.uni-one.net">Uni-One</option>
<option value="server2.uniserver.nl">Uniserver</option>
<option value="mail.urcentral.com">Urcentral</option>
<option value="mail.utronix.nl">Utronix</option>
<option value="pop1.inter.nl.net">UUnet(2)Internl.net</option>
<option value="193.67.237.8">UUnet(3)/internl.net</option>
<option value="pop3.NL.net">UUnet/Worldcom</option>
<option value="mx1.uwnet.nl">Uwnet</option>
<option value="mailhost.veteranen.nl">Veteranen</option>
<option value="mail.vevida.nl">Vevida (1)</option>
<option value="pop0.vevida.nl">Vevida (2)</option>
<option value="pop1.vevida.nl">Vevida (3)</option>
<option value="pop3.vizzavi.nl">Vizzavi</option>
<option value="mail.vobisnet.nl">Vobisnet</option>
<option value="mxhost.voetbalonline.nl">Voetbal Online</option>
<option value="pop3.voetbal.nl">Voetbal.nl</option>
<option value="mail.vst-online.net">VST Online</option>
<option value="pop.vuurwerk.nl">Vuurwerk</option>
<option value="pop.wanadoo.nl">Wanadoo</option>
<option value="pop.cablewanadoo.nl">Wanadoo(cable)</option>
<option value="pop.webconnect.nl">Webconnect</option>
<option value="www.webhosting.nl">Webhosting</option>
<option value="pop3.concepts.nl">WestBrabantNet</option>
<option value="mail.windkracht.nl">Windkracht</option>
<option value="mail.windo.nl">Windonet</option>
<option value="194.165.93.194">Wirehub</option>
<option value="pop3.wish.net">Wish(1)</option>
<option value="mail.wish.net">Wish(2)</option>
<option value="relay1.wolmail.nl">Wolmail(1)</option>
<option value="pop3.wolmail.nl">Wolmail(2)</option>
<option value="pop.worldbase.nl">Worldbase</option>
<option value="mail.worldcity.nl">Worldcity</option>
<option value="pop.worldonline.nl">Worldonline(1)</option>
<option value="pop3-2.worldonline.nl">Worldonline(2)</option>
<option value="pop3.wwxs.nl">WWXS</option>
<option value="pop.wxs.nl">WXS</option>
<option value="pop3.x-stream.nl">X-Stream</option>
<option value="pop.xs4all.nl">Xs4all</option>
<option value="mail.zeelandnet.nl">Zeelandnet</option>
<option value="pop3.zonnet.nl">Zonnet</option>
</select>
or popserver <input type="text" name="servername">
username <input type="text" name="username">
password <input type="password" name="password">
<input type="submit" value="login">
<input type="button" value="new" onClick="CreateNewMail('new');">
<input type="button" value="reply" onClick="CreateNewMail('reply');">
<input type="button" value="forward" onClick="CreateNewMail('forward');">
</form>
</body>
</html>
  EOF
}

sub PrintList($$$)
{
  my $serverName = shift;
  my $userName = shift;
  my $passWord = shift;

  print "Content-type: text/html\n\n";
  print <<"  EOF";
<html>
<head>
<title>WebMail</title>
<link rel="stylesheet" href="$stylesheetURL">
  EOF
  if ($serverName =~ m/^([a-zA-Z0-9\.-]+)$/)
  {
    $serverName = $1;
    my $pop = new Mail::POP3Client ('HOST' => $serverName, 'USER' => $userName, 'PASSWORD' => $passWord);
    if ($pop->Count() < 0)
    {
      print "</head>\n<body>\nAn error has occurred: " . $pop->Message();
    }
    elsif ($pop->Count() == 0)
    {
      print "</head>\n<body>\nNo messages.";
    }
    else
    {
      print <<"      EOF";
<script>
var HighLightedRowObject = -1;
function TrClick(objectTR, messageId)
{
  parent.frames["bottom"].document.body.innerHTML = messagesArray[messageId];
  if (HighLightedRowObject != -1)
  {
    HighLightedRowObject.className = '';
  }
  objectTR.className = 'clicked';
  HighLightedRowObject = objectTR;
}
function TrOver(objectTR)
{
  if (objectTR.className != 'clicked')
  {
    objectTR.className = 'over';
  }
}
function TrOut(objectTR)
{
  if (objectTR.className != 'clicked')
  {
    objectTR.className = '';
  }
}

var messagesArray = new Array();
      EOF
      my $parser = MIME::Parser->new;
      ### make the parser output to memory NOT to disc
      $parser->output_to_core(1);
      ### what does this option do? Should it be used or not? JSJ needs to fix this
      $parser->output_to_core('ALL');
      my $messageIndexHTML = '';
      ### Loop through all the messages on the popserver
      for (my $i = 1; $i <= $pop->Count(); $i++)
      {
        print "messagesArray[$i] = '";
        my $messageBody = $pop->HeadAndBody($i);
        my $ent = $parser->parse_data($messageBody);
        my $head = $ent->head();
        my $subject = $head->get('Subject');
        my $encoding = $ent->head()->mime_encoding();
        my $contentType = $ent->effective_type;
        my $textplain = -1;
        my $texthtml = -1;
        ### If the message is multipart, find the html and the plaintext part
        if ($contentType =~ m/multipart/)
        {
          for (my $partNumber = 0; $partNumber < $ent->parts; $partNumber++)
          {
            if ($ent->parts($partNumber)->effective_type eq "text/plain")
            {
              $textplain = $partNumber;
            }
            elsif ($ent->parts($partNumber)->effective_type eq "text/html")
            {
              $texthtml = $partNumber;
            }
          }
          my $selectedPart = 0;
          ### If one part is html, use that
          if ($texthtml >= 0)
          {
            $selectedPart = $texthtml;
          }
          ### Or else use the plaintext part
          elsif ($textplain >= 0)
          {
            $selectedPart = $textplain;
          }
          $encoding = $ent->parts($selectedPart)->head->mime_encoding;
          $contentType = $ent->parts($selectedPart)->effective_type;
          ### Tell the mime parser to use the selected part and ignore the rest
          my $newent = MIME::Entity->build(Data => $ent->parts($selectedPart)->body_as_string);
          $ent->parts([$newent]);
          $ent->make_singlepart; 
          $ent->sync_headers('Length' => 'COMPUTE', 'Nonstandard' => 'ERASE');
        }
        #print JavascriptEncodeText("\$encoding: $encoding\n\n\$contentType: $contentType\n\n\$body:\n" . $ent->body_as_string);
        ### Decode the message from quotedprintable or base64 encoding
        if ($encoding =~ /uot/)
        {
          print JavascriptEncodeHTML(decode_qp($ent->body_as_string));
        }
        elsif ($encoding =~ /ase/)
        {
          print JavascriptEncodeHTML(decode_base64($ent->body_as_string));
        }
        else
        {
          print '<html><body>' . JavascriptEncodeText($ent->body_as_string) . '</body></html>';
        }
        my $fromName = '';
        my $fromAddress = $head->get('From');
        ### Split the mime 'From' into a name and and address section
        if ($head->get('From') =~ m/^('|"|)(.*?)\1\s*<(.*?)>\s*$/)
        {
          $fromName = $2;
          $fromAddress = $3;
        }
        elsif ($head->get('From') =~ m/^(.*?) \((.*?)\)\s*$/)
        {
          $fromName = $2;
          $fromAddress = $1;
        }
        my $messageDate = $head->get('Date');
        ### Convert the mime date to a more readable date using timelocal and localtime
        if ($messageDate =~ m/^[a-zA-Z]+\, ([0-9]+) ([a-zA-Z]+) ([0-9]+) ([0-9]+)\:([0-9]+)\:([0-9]+) ([0-9\+\-]+)/)
        {
          my %months = ("Jan" => 0, "Feb"=> 1, "Mar" => 2, "Apr"=> 3, "May" => 4, "Jun"=> 5, "Jul" => 6, "Aug" => 7, "Sep" => 8, "Oct"=> 9, "Nov" => 10, "Dec" => 11);
          $messageDate = timelocal($6, $5, $4, $1, $months{$2}, $3);
          $messageDate -= 60 * $7;
          my @date = localtime($messageDate);
          $messageDate = sprintf ("%04d-%02d-%02d %02d:%02d", $date[5] + 1900, $date[4] + 1, $date[3], $date[2], $date[1]);
        }
        $messageIndexHTML .= "<tr onMouseOver=\"TrOver(this);\" onMouseOut=\"TrOut(this);\" onClick=\"TrClick(this, $i);\"><td>" . JavascriptEncodeText($fromName) . "</td><td>" . JavascriptEncodeText($fromAddress) . "</td>";
        $messageIndexHTML .= "<td>" . JavascriptEncodeText($subject) . "</td><td>" . JavascriptEncodeText($messageDate) . "</td></tr>\n";

        print "';\n\n";
      }

      print <<"      EOF";
</script>
<style>
body
{
  background-color: #FFFFFF;
  color: #000000;
}
</style>
</head>
<body>
<table width="100%">
<tr><th colspan="2">From</th><th>Subject</th><th>Date</th></tr>
$messageIndexHTML</table>
      EOF
    }
    $pop->Close();
  }
  print "\n</body>\n</html>\n";
}

sub SendMail($$$$$)
{
  my $to = shift;
  my $cc = shift;
  my $bcc = shift;
  my $subject = shift;
  my $content = shift;
  print "Content-type: text/html\n\n";
  if ($to =~ m/^([a-zA-Z0-9\_\.]+\@[a-zA-Z0-9\_\.]+)$/)
  {
    $to = $1;
    $subject =~ s/\'/\\'/g;
    if ($subject =~ m/^(.*)$/)
    {
      $subject = $1;
      if (open (MAIL, "|$sendmailExec -s '$subject' $to"))
      {
        print MAIL $content;
        close (MAIL);
        print "<html><body onLoad=\"window.close()\"></body></html>";
      }
      else
      {
        print "<html><body>An error occurred: $!<br>Could not send message.<br><a href=\"javascript:history.go(-1)\">back</a>\n</body></html>";
      }
    }
    else
    {
      print "<html><body>An error occurred: the subject contains illegal characters.<br><a href=\"javascript:history.go(-1)\">back</a>\n</body></html>";
    }
  }
  else
  {
    print "<html><body>An error occurred: the to: emailaddress contains illegal characters.<br><a href=\"javascript:history.go(-1)\">back</a>\n</body></html>";
  }
  ### Mail::Sender?
  #if (my $smtp = Net::SMTP->new($SMTPServerName))
  #{
  #  $smtp->mail('WebMail');
  #  $smtp->to($to);
  #  $smtp->data();
  #  $smtp->datasend("To: $to\n");
  #  if ($cc)
  #  {
  #    $smtp->datasend("Cc: $cc\n");
  #  }
  #  if ($bcc)
  #  {
  #    $smtp->datasend("Bcc: $bcc\n");
  #  }
  #  $smtp->datasend("Subject: $subject\n");
  #  $smtp->datasend("\n");
  #  $smtp->datasend($content);
  #  $smtp->dataend();
  #  $smtp->quit;
  #  print "<html><body onLoad=\"window.close()\"></body></html>";
  #}
  #else
  #{
  #  print "<html><body>An error occurred: Could not send message.<br><a href=\"javascript:history.go(-1)\">back</a>\n</body></html>";
  #}
}

sub PrintStylesheet()
{
  print "Content-type: text/css\n";
  print "Expires: Wednesday, 23-Oct-22 05:29:10 GMT", "\n\n";
  print <<"  EOF";
body
{
  margin: 0px;
  background-color: #121C73;
  font-family: Verdana, Tahoma, Arial, Helvetica, sans-serif;
  font-size: 11px;
  color: #FFFFFF;
  line-height: 16px;
}
a
{
  color: #0000CC;
  text-decoration: none;
}
a:hover
{
  color: #FF0000;
  text-decoration: underline;
}
form
{
  display: inline;
  padding: 0px;
  margin: 0px;
}
input,select,textarea
{
  background-color: #0E165C;
  background-image: url("/formbg.gif");
  background-attachment: fixed;
  color: #ffffff;
  border-left-style: solid;
  border-left-color: #5A619E;
  border-left-width: 1px;
  border-right-style: solid;
  border-right-color: #5A619E;
  border-right-width: 1px;
  border-top-style: solid;
  border-top-color: #5A619E;
  border-top-width: 1px;
  border-bottom-style: solid;
  border-bottom-color: #5A619E;
  border-bottom-width: 1px;
  font-family: Verdana, Tahoma, Arial, Helvetica, sans-serif;
  font-size: 11px;
  scrollbar-base-color:#0E165C;
}
table
{
  font-size: 10pt;
  border-collapse: collapse;
}
th
{
  background-color: #99CCFF;
  color: #000000;
  text-align: left;
}
tr.over
{
  background-color: #99CCFF;
  color: #000000;
  cursor: default;
}
tr.clicked
{ background-color: #FFCC99;
  color: #000000;
  cursor: default;
}
  EOF
}

### Main program ###

if ($cgi->param())
{
  if ($cgi->param('action'))
  {
    if ($cgi->param('action') eq 'PrintFrameset2')
    {
      PrintFrameset2();
    }
    elsif ($cgi->param('action') eq 'PrintToolbar')
    {
      PrintToolbar();
    }
    elsif ($cgi->param('action') eq 'PrintList')
    {
      PrintList($cgi->param('servername'), $cgi->param('username'), $cgi->param('password'));
    }
    elsif ($cgi->param('action') eq 'PrintStylesheet')
    {
      PrintStylesheet();
    }
    elsif ($cgi->param('action') eq 'SendMail')
    {
      SendMail($cgi->param('to'), $cgi->param('cc'), $cgi->param('bcc'), $cgi->param('subject'), $cgi->param('content'));
    }
    elsif ($cgi->param('action') eq 'PrintSendMessageForm')
    {
      PrintSendMessageForm();
    }
    elsif ($cgi->param('action') eq 'PrintSplash')
    {
      PrintSplash();
    }
  }
}
else
{
  PrintFrameset();
}
