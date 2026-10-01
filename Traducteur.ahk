; ==============================================================
;  Traducteur
;  - Ctrl+Entrée : traduit ton texte dans la langue choisie, puis l'envoie
;  - Triple-clic : traduit le texte visé dans ta langue (bulle)
;  - Pastille : glisser pour la déplacer, clic droit pour le menu
;  L'interface s'affiche dans « ma langue ».
;  Fonctionne dans toutes les applications : le script agit comme ton clavier.
;  AutoHotkey v2 - Windows
; ==============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
CoordMode "Mouse", "Screen"

; ---------- Réglages (tu peux les modifier) ----------
; Langues proposées : code Google + nom de la langue dans cette langue.
; Les phrases de l'interface de chaque langue sont en bas du fichier (ChargerTextes).
LANGUES := [
    ["de", "Deutsch"], ["en", "English"], ["es", "Español"], ["fr", "Français"], ["nl", "Nederlands"],
    ["no", "Norsk"], ["pl", "Polski"], ["pt", "Português"], ["ro", "Română"]
]

APPS_EXCLUES         := ""       ; applis où Ctrl+Entrée garde son rôle normal, ex : "WINWORD.EXE,OUTLOOK.EXE"
LONGUEUR_MAX         := 2000     ; taille maxi d'un message traduit avec Ctrl+Entrée
LONGUEUR_MAX_LECTURE := 4000     ; taille maxi d'un texte lu (au-delà, seul le début est traduit)
DELAI_COLLAGE        := 200      ; ms entre le collage de la traduction et l'envoi
DELAI_PRESSE_PAPIERS := 300      ; ms avant de remettre ton presse-papiers d'origine
LARGEUR_BULLE        := 420      ; largeur maxi de la bulle (pixels à 100 %)
COULEUR_PASTILLE     := "5865F2"
URL_GOOGLE           := "https://translate-pa.googleapis.com/v1/translate"
; Fenêtres jamais touchées : les terminaux, où Ctrl+C arrêterait le programme en cours
CLASSES_EXCLUES      := "ConsoleWindowClass,CASCADIA_HOSTING_WINDOW_CLASS,PuTTY,mintty,VirtualConsoleClass"

; ---------- État ----------
TEXTES := Map()
ChargerTextes()
FichierIni := A_AppData "\Traducteur\reglages.ini"
RaccourciDemarrage := A_Startup "\Traducteur.lnk"
Echelle := A_ScreenDPI / 96
DOUBLE_CLIC := DllCall("GetDoubleClickTime")
TOLERANCE_CLIC := Max(SysGet(36), 4)               ; écart maxi entre les 3 clics (pixels)

MaLangue := IniRead(FichierIni, "Langues", "Ma", "fr")
LangueContact := IniRead(FichierIni, "Langues", "Contact", "en")
if !LangueConnue(MaLangue)
    MaLangue := "fr"
if !LangueConnue(LangueContact) || (LangueContact = MaLangue)
    LangueContact := (MaLangue = "en") ? "fr" : "en"
LectureActive := (IniRead(FichierIni, "General", "Lecture", "1") = "1")

EnCours := false
NbClics := 0, DernierClic := 0, PremierX := 0, PremierY := 0
Bulle := "", BulleTexte := "", LienCopier := 0
MenuMaLangue := "", MenuContact := ""

; ---------- Pastille ----------
HauteurP := Round(26 * Echelle)
MargeP := Round(12 * Echelle)
LargeurP := MesurerTexte(LibellePastille(), "s10 bold").w + 2 * MargeP

; +E0x08000000 = la pastille ne prend jamais le focus : ta fenêtre reste au premier plan
Pastille := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "Traducteur")
Pastille.MarginX := 0
Pastille.MarginY := 0
Pastille.BackColor := COULEUR_PASTILLE
Pastille.SetFont("s10 bold cWhite", "Segoe UI")
TexteP := Pastille.Add("Text", "x0 y0 w" LargeurP " h" HauteurP " Center 0x200 0x80 Background" COULEUR_PASTILLE, LibellePastille())

PositionParDefaut(&px, &py)
px := IniRead(FichierIni, "Pastille", "X", px)
py := IniRead(FichierIni, "Pastille", "Y", py)
if !(IsInteger(px) && IsInteger(py) && PositionVisible(px, py))
    PositionParDefaut(&px, &py)
Pastille.Show("x" px " y" py " w" LargeurP " h" HauteurP " NoActivate")
ArrondirPastille()
WinSetTransparent(240, "ahk_id " Pastille.Hwnd)

OnMessage(0x201, ClicGauchePastille)   ; glisser la pastille
OnMessage(0x205, ClicDroitPastille)    ; menu
OnMessage(0x20, Curseur)               ; curseur adapté au survol

; Menu : clic droit sur la pastille ou sur l'icône près de l'horloge
MettreAJourLangues(false)

; ---------- Raccourcis ----------
HotIf (*) => !EcritureExclue()
Hotkey "^Enter", TraduireEtEnvoyer
Hotkey "^NumpadEnter", TraduireEtEnvoyer
HotIf (*) => LectureActive || BulleOuverte()
Hotkey "~LButton", ClicGaucheGlobal
HotIf (*) => BulleOuverte()
Hotkey "Esc", (*) => FermerBulle()
HotIf

; Petit mode d'emploi au tout premier lancement
if (IniRead(FichierIni, "General", "DejaLance", "0") != "1") {
    TrayTip TexteUI("accueil"), "Traducteur", 1
    try {
        CreerDossierReglages()
        IniWrite "1", FichierIni, "General", "DejaLance"
    }
}
return


; ==============================================================
;  Écrire : Ctrl+Entrée = traduire puis envoyer
; ==============================================================
TraduireEtEnvoyer(*) {
    global EnCours
    if EnCours
        return
    EnCours := true
    sauvegarde := ClipboardAll()
    try {
        ; 1. Copier le texte de la zone de saisie
        A_Clipboard := ""
        Send "^a"
        Sleep 30
        Send "^c"
        if !ClipWait(1)
            return                                   ; zone vide : rien à faire
        texte := StrReplace(A_Clipboard, "`r`n", "`n")
        if (Trim(texte, " `t`n") = "")
            return

        ; 2. Les commandes (/...) partent telles quelles
        if (SubStr(LTrim(texte, " `t`n"), 1, 1) = "/") {
            Send "{Enter}"
            return
        }
        if (StrLen(texte) > LONGUEUR_MAX)
            throw Error(TexteUI("err_trop_long", LONGUEUR_MAX))

        ; 3. Traduire dans la langue choisie
        traduction := TraduireGoogle(texte, LangueContact, &langueSource)
        if (StrLen(traduction) > LONGUEUR_MAX)
            throw Error(TexteUI("err_trop_long", LONGUEUR_MAX))

        ; 4. Remplacer par la traduction (sauf si c'est déjà la bonne langue), puis envoyer
        if !MemeLangue(langueSource, LangueContact) {
            A_Clipboard := traduction
            Send "^v"
            Sleep DELAI_COLLAGE
        }
        Send "{Enter}"
    } catch as erreur {
        Prevenir(TexteUI("err_titre") "`n" erreur.Message "`n" TexteUI("err_non_envoye"))
    } finally {
        Sleep DELAI_PRESSE_PAPIERS
        A_Clipboard := sauvegarde                    ; on remet ce que tu avais copié avant
        EnCours := false
    }
}


; ==============================================================
;  Lire : triple-clic = bulle de traduction
; ==============================================================
ClicGaucheGlobal(*) {
    global NbClics, DernierClic, PremierX, PremierY
    MouseGetPos &x, &y, &fenetre
    ; clic hors de la bulle : elle se ferme une fois les clics terminés
    if BulleOuverte() && (fenetre != Bulle.Hwnd)
        SetTimer FermerBulle, -DOUBLE_CLIC
    if !LectureActive || (fenetre = Pastille.Hwnd) || (IsObject(Bulle) && fenetre = Bulle.Hwnd)
        || FenetreExclue(fenetre)
        return
    ; 3 clics rapides au même endroit
    if (A_TickCount - DernierClic > DOUBLE_CLIC)
        || (Abs(x - PremierX) > TOLERANCE_CLIC) || (Abs(y - PremierY) > TOLERANCE_CLIC) {
        NbClics := 0
        PremierX := x
        PremierY := y
    }
    NbClics += 1
    DernierClic := A_TickCount
    if (NbClics = 3) {
        NbClics := 0
        CopierSelection(x, y)
    }
}

CopierSelection(x, y) {
    KeyWait "LButton", "T1"                          ; on laisse l'appli finir la sélection
    Sleep 60
    sauvegarde := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    texte := ClipWait(0.5) ? A_Clipboard : ""
    A_Clipboard := sauvegarde
    texte := Trim(StrReplace(texte, "`r`n", "`n"), " `t`n")
    if (texte != "")
        SetTimer LireTexte.Bind(texte, x, y), -1     ; la traduction se fait à part : la souris reste libre
}

LireTexte(texte, mx, my) {
    coupe := StrLen(texte) > LONGUEUR_MAX_LECTURE
    if coupe
        texte := SubStr(texte, 1, LONGUEUR_MAX_LECTURE)
    try {
        traduction := TraduireGoogle(texte, MaLangue, &source)
    } catch as erreur {
        Prevenir(TexteUI("err_titre") "`n" erreur.Message)
        return
    }
    if MemeLangue(source, MaLangue)
        return                                       ; déjà dans ta langue : pas de bulle
    AfficherBulle(traduction . (coupe ? " […]" : ""), source, MaLangue, mx, my)
}

AfficherBulle(texte, source, cible, mx, my) {
    global Bulle, BulleTexte, LienCopier
    SetTimer FermerBulle, 0                          ; annule une fermeture en attente
    FermerBulle()
    BulleTexte := texte
    marge := Round(12 * Echelle)
    ecart := Round(16 * Echelle)
    entete := NomLangue(source) " → " NomLangue(cible)
    copier := TexteUI("copier")
    lEntete := MesurerTexte(entete, "s9").w
    lCopier := MesurerTexte(copier, "s9").w + 2
    lTexte := MesurerTexte(texte, "s11").w + 2
    largeur := Max(Min(lTexte, Round(LARGEUR_BULLE * Echelle)), lEntete + ecart + lCopier)

    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "Traduction")
    g.BackColor := "2B2D31"
    g.MarginX := marge
    g.MarginY := marge
    g.SetFont("s9", "Segoe UI")
    g.Add("Text", "xm ym 0x80 c949BA4 w" (largeur - lCopier), entete)
    lien := g.Add("Text", "x+0 yp 0x80 Right c00A8FC w" lCopier, copier)
    lien.OnEvent("Click", CopierBulle)
    LienCopier := lien.Hwnd
    g.SetFont("s11", "Segoe UI")
    g.Add("Text", "xm y+" Round(6 * Echelle) " 0x80 cDBDEE1 w" largeur, texte)
    g.Show("Hide")
    g.GetPos(, , &l, &h)

    ; près de la souris, sans jamais sortir de l'écran
    EcranSous(mx, my, &gauche, &haut, &droite, &bas)
    x := mx + Round(14 * Echelle)
    y := my + Round(18 * Echelle)
    if (x + l > droite)
        x := droite - l - 4
    if (y + h > bas)
        y := my - h - Round(10 * Echelle)
    x := Max(x, gauche + 4)
    y := Max(y, haut + 4)
    g.Show("x" x " y" y " NoActivate")
    WinSetRegion("0-0 w" l " h" h " r" Round(16 * Echelle) "-" Round(16 * Echelle), "ahk_id " g.Hwnd)
    Bulle := g
}

CopierBulle(*) {
    A_Clipboard := BulleTexte
    ToolTip TexteUI("copie")
    SetTimer () => ToolTip(), -1200
    SetTimer FermerBulle, -10
}

BulleOuverte(*) {
    return IsObject(Bulle) && DllCall("IsWindowVisible", "Ptr", Bulle.Hwnd)
}

FermerBulle(*) {
    global Bulle
    if IsObject(Bulle) {
        Bulle.Destroy()
        Bulle := ""
    }
}

BasculerLecture(*) {
    global LectureActive
    LectureActive := !LectureActive
    ConstruireMenu()
    try {
        CreerDossierReglages()
        IniWrite LectureActive ? "1" : "0", FichierIni, "General", "Lecture"
    }
    ToolTip TexteUI(LectureActive ? "lecture_on" : "lecture_off")
    SetTimer () => ToolTip(), -1500
}


; ==== FONCTIONS DE TRADUCTION ====
TraduireGoogle(texte, cible, &source) {
    url := URL_GOOGLE
        . "?params.client=gtx&dataTypes=TRANSLATION"
        . "&key=AIzaSyDLEeFI5OtFBwYBIoK_jj5m32rZK5CkCXA"
        . "&query.sourceLanguage=auto"
        . "&query.targetLanguage=" cible
        . "&query.text=" EncoderURL(texte)
    try {
        requete := ComObject("WinHttp.WinHttpRequest.5.1")
        requete.Open("GET", url, true)               ; asynchrone : la souris reste fluide pendant l'attente
        requete.SetTimeouts(5000, 5000, 5000, 10000)
        requete.Send()
        debut := A_TickCount
        while !requete.WaitForResponse(0.02) {
            if (A_TickCount - debut > 10000)
                throw Error("timeout")
            Sleep 10
        }
        statut := requete.Status
    } catch {
        throw Error(TexteUI("err_connexion"))
    }
    if (statut != 200)
        throw Error(TexteUI("err_refus", statut))

    reponse := LireReponseUTF8(requete)
    traduction := LireChaineJSON(reponse, "translation")
    if (traduction = "")
        throw Error(TexteUI("err_reponse"))
    source := LireChaineJSON(reponse, "sourceLanguage")
    return traduction
}

; Encode le texte pour l'adresse web (UTF-8, accents et emojis compris)
EncoderURL(texte) {
    taille := StrPut(texte, "UTF-8")
    tampon := Buffer(taille)
    StrPut(texte, tampon, "UTF-8")
    resultat := ""
    loop taille - 1 {                                ; -1 : on ignore le zéro final
        o := NumGet(tampon, A_Index - 1, "UChar")
        if (o >= 0x30 && o <= 0x39) || (o >= 0x41 && o <= 0x5A) || (o >= 0x61 && o <= 0x7A)
            || o = 0x2D || o = 0x2E || o = 0x5F || o = 0x7E
            resultat .= Chr(o)
        else
            resultat .= Format("%{:02X}", o)
    }
    return resultat
}

; Lit la réponse en UTF-8 (sinon les accents et emojis peuvent être abîmés)
LireReponseUTF8(requete) {
    corps := requete.ResponseBody
    taille := corps.MaxIndex() + 1
    donnees := NumGet(ComObjValue(corps) + 8 + A_PtrSize, "Ptr")
    return StrGet(donnees, taille, "UTF-8")
}

; Extrait la valeur texte d'une clé dans la réponse JSON de Google
LireChaineJSON(json, cle) {
    if !RegExMatch(json, '"' cle '"\s*:\s*"', &m)
        return ""
    i := m.Pos + m.Len
    resultat := ""
    loop {
        c := SubStr(json, i, 1)
        if (c = "")
            throw Error(TexteUI("err_reponse"))
        if (c = '"')
            break
        if (c != "\") {
            resultat .= c
            i += 1
            continue
        }
        e := SubStr(json, i + 1, 1)
        i += 2
        switch e, true {
            case "n": resultat .= "`n"
            case "r": resultat .= "`r"
            case "t": resultat .= "`t"
            case "b": resultat .= Chr(8)
            case "f": resultat .= Chr(12)
            case "u":
                code := Integer("0x" SubStr(json, i, 4))
                i += 4
                ; emojis encodés en deux morceaux (😄)
                if (code >= 0xD800 && code <= 0xDBFF && SubStr(json, i, 2) = "\u") {
                    bas := Integer("0x" SubStr(json, i + 2, 4))
                    if (bas >= 0xDC00 && bas <= 0xDFFF) {
                        code := 0x10000 + ((code - 0xD800) << 10) + (bas - 0xDC00)
                        i += 6
                    }
                }
                resultat .= Chr(code)
            default: resultat .= e                   ; \"  \\  \/
        }
    }
    return resultat
}
; ==== FIN FONCTIONS DE TRADUCTION ====


; ==============================================================
;  Langues
; ==============================================================
ChoisirMaLangue(code, *) {
    global MaLangue, LangueContact
    if (code = LangueContact)                        ; même langue des deux côtés : on échange
        LangueContact := MaLangue
    MaLangue := code
    MettreAJourLangues()
}

ChoisirLangueContact(code, *) {
    global MaLangue, LangueContact
    if (code = MaLangue)
        MaLangue := LangueContact
    LangueContact := code
    MettreAJourLangues()
}

InverserLangues(*) {
    global MaLangue, LangueContact
    temp := MaLangue
    MaLangue := LangueContact
    LangueContact := temp
    MettreAJourLangues()
}

MettreAJourLangues(sauver := true) {
    A_IconTip := "Traducteur : " NomLangue(MaLangue) " → " NomLangue(LangueContact)
    MettreAJourPastille()
    ConstruireMenu()                                 ; le menu suit « ma langue »
    if sauver {
        try {
            CreerDossierReglages()
            IniWrite MaLangue, FichierIni, "Langues", "Ma"
            IniWrite LangueContact, FichierIni, "Langues", "Contact"
        }
        ToolTip NomLangue(MaLangue) " → " NomLangue(LangueContact)
        SetTimer () => ToolTip(), -2000
    }
}

LangueConnue(code) {
    for l in LANGUES
        if (l[1] = code)
            return true
    return false
}

; Nom affiché d'une langue (Google peut renvoyer "zh-CN" ou "zh", "pt-PT" ou "pt"...)
NomLangue(code) {
    for l in LANGUES
        if (l[1] = code)
            return l[2]
    for l in LANGUES
        if MemeLangue(l[1], code)
            return l[2]
    return StrUpper(code)
}

MemeLangue(a, b) {
    return SubStr(a, 1, 2) = SubStr(b, 1, 2)
}

CodeCourt(code) {
    return StrUpper(SubStr(code, 1, 2))
}

; Phrase de l'interface dans « ma langue » (à défaut en anglais), {1} remplacé par la valeur donnée
TexteUI(cle, valeurs*) {
    for langue in [MaLangue, "en", "fr"]
        if TEXTES.Has(langue) && TEXTES[langue].Has(cle)
            return Format(TEXTES[langue][cle], valeurs*)
    return cle
}


; ==============================================================
;  Menu
; ==============================================================
ConstruireMenu() {
    global MenuMaLangue, MenuContact
    MenuMaLangue := Menu()
    MenuContact := Menu()
    for l in LANGUES {
        MenuMaLangue.Add(l[2], ChoisirMaLangue.Bind(l[1]), "Radio")
        MenuContact.Add(l[2], ChoisirLangueContact.Bind(l[1]), "Radio")
        if (l[1] = MaLangue)
            MenuMaLangue.Check(l[2])
        if (l[1] = LangueContact)
            MenuContact.Check(l[2])
    }
    m := A_TrayMenu
    m.Delete()
    ; aide (lignes grisées)
    aide := [TexteUI("ecrire") "`t" TexteUI("touche_ecrire"),
             TexteUI("lire") (LectureActive ? "" : " " TexteUI("desactive")) "`t" TexteUI("touche_lire"),
             TexteUI("deplacer") "`t" TexteUI("touche_deplacer")]
    for ligne in aide {
        m.Add(ligne, Rien)
        m.Disable(ligne)
    }
    m.Add()
    m.Add(TexteUI("lecture"), BasculerLecture)
    if LectureActive
        m.Check(TexteUI("lecture"))
    m.Add(TexteUI("ma_langue"), MenuMaLangue)
    m.Add(TexteUI("langue_trad"), MenuContact)
    m.Add(TexteUI("inverser"), InverserLangues)
    m.Add()
    m.Add(TexteUI("afficher"), AfficherMasquerPastille)
    if DllCall("IsWindowVisible", "Ptr", Pastille.Hwnd)
        m.Check(TexteUI("afficher"))
    m.Add(TexteUI("replacer"), ReplacerPastille)
    m.Add(TexteUI("demarrage"), DemarrageWindows)
    if FileExist(RaccourciDemarrage)
        m.Check(TexteUI("demarrage"))
    m.Add()
    m.Add(TexteUI("quitter"), (*) => ExitApp())
}

Rien(*) {
}


; ==============================================================
;  Pastille et réglages
; ==============================================================
LibellePastille() {
    return CodeCourt(MaLangue) " → " CodeCourt(LangueContact) " : CTRL + ENTER"
}

MettreAJourPastille() {
    global LargeurP
    texte := LibellePastille()
    LargeurP := MesurerTexte(texte, "s10 bold").w + 2 * MargeP
    TexteP.Value := texte
    TexteP.Move(0, 0, LargeurP, HauteurP)
    Pastille.Move(, , LargeurP, HauteurP)
    ArrondirPastille()
}

ArrondirPastille() {
    WinSetRegion("0-0 w" LargeurP " h" HauteurP " r" HauteurP "-" HauteurP, "ahk_id " Pastille.Hwnd)
}

Colorer(couleur) {
    Pastille.BackColor := couleur
    TexteP.Opt("Background" couleur)
    TexteP.Redraw()
}

Prevenir(message) {
    SoundPlay "*48"
    Colorer("ED4245")                                ; la pastille clignote en rouge
    SetTimer () => Colorer(COULEUR_PASTILLE), -1500
    ToolTip message
    SetTimer () => ToolTip(), -4000
}

; Mesure la taille d'un texte en pixels, avec une police donnée
MesurerTexte(texte, optionsPolice) {
    g := Gui("-DPIScale")
    g.SetFont(optionsPolice, "Segoe UI")
    c := g.Add("Text", "0x80", texte)
    c.GetPos(, , &l, &h)
    g.Destroy()
    return {w: l, h: h}
}

; Ctrl+Entrée garde son rôle normal dans les terminaux et les applis de APPS_EXCLUES
EcritureExclue(*) {
    try {
        fenetre := WinExist("A")
        exe := WinGetProcessName("ahk_id " fenetre)
    } catch {
        return false
    }
    if FenetreExclue(fenetre)
        return true
    return (APPS_EXCLUES != "") && InStr("," StrReplace(APPS_EXCLUES, " ") ",", "," exe ",")
}

FenetreExclue(fenetre) {
    try {
        classe := WinGetClass("ahk_id " fenetre)
    } catch {
        return false
    }
    return InStr("," CLASSES_EXCLUES ",", "," classe ",")
}

EstPastille(hwnd) {
    g := GuiFromHwnd(hwnd, true)
    return IsObject(g) && g.Hwnd = Pastille.Hwnd
}

ClicGauchePastille(wParam, lParam, msg, hwnd) {
    if !EstPastille(hwnd)
        return
    fenetreActive := WinExist("A")
    PostMessage 0xA1, 2, 0, , "ahk_id " Pastille.Hwnd   ; la faire glisser
    KeyWait "LButton"
    WinGetPos &x, &y, , , "ahk_id " Pastille.Hwnd
    SauverPosition(x, y)
    ; on rend la main à la fenêtre d'avant
    if (fenetreActive && WinExist("A") = Pastille.Hwnd)
        try WinActivate("ahk_id " fenetreActive)
    return 0
}

ClicDroitPastille(wParam, lParam, msg, hwnd) {
    if !EstPastille(hwnd)
        return
    fenetreActive := WinExist("A")
    A_TrayMenu.Show()
    if fenetreActive
        try WinActivate("ahk_id " fenetreActive)
    return 0
}

Curseur(wParam, lParam, msg, hwnd) {
    if EstPastille(wParam)
        forme := 32646                               ; flèches de déplacement
    else if (LienCopier && wParam = LienCopier)
        forme := 32649                               ; main
    else
        return
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", forme, "Ptr"))
    return true
}

AfficherMasquerPastille(*) {
    if DllCall("IsWindowVisible", "Ptr", Pastille.Hwnd)
        Pastille.Hide()
    else
        Pastille.Show("NoActivate")
    ConstruireMenu()
}

ReplacerPastille(*) {
    PositionParDefaut(&x, &y)
    Pastille.Move(x, y)
    if !DllCall("IsWindowVisible", "Ptr", Pastille.Hwnd)
        AfficherMasquerPastille()
    SauverPosition(x, y)
}

PositionParDefaut(&x, &y) {
    MonitorGetWorkArea(MonitorGetPrimary(), , , &droite, &bas)
    x := droite - LargeurP - Round(24 * Echelle)
    y := bas - HauteurP - Round(24 * Echelle)
}

PositionVisible(x, y) {
    ; vérifie que la pastille tient sur un des écrans (utile si un écran a été débranché)
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &g, &h, &d, &b)
        if (x >= g && y >= h && x + LargeurP <= d && y + HauteurP <= b)
            return true
    }
    return false
}

EcranSous(x, y, &gauche, &haut, &droite, &bas) {
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &gauche, &haut, &droite, &bas)
        if (x >= gauche && x < droite && y >= haut && y < bas)
            return
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &gauche, &haut, &droite, &bas)
}

SauverPosition(x, y) {
    try {
        CreerDossierReglages()
        IniWrite x, FichierIni, "Pastille", "X"
        IniWrite y, FichierIni, "Pastille", "Y"
    }
}

CreerDossierReglages() {
    SplitPath FichierIni, , &dossier
    DirCreate dossier
}

DemarrageWindows(*) {
    if FileExist(RaccourciDemarrage)
        FileDelete RaccourciDemarrage
    else
        FileCreateShortcut A_ScriptFullPath, RaccourciDemarrage, A_ScriptDir
    ConstruireMenu()
}


; ==============================================================
;  Phrases de l'interface, dans chaque langue
;  Pour ajouter une langue : copie un bloc, change le code et traduis les phrases.
;  Une phrase absente est affichée en anglais. \n = retour à la ligne, {1} = valeur.
; ==============================================================
AjouterTextes(code, bloc) {
    phrases := Map()
    loop parse bloc, "`n", "`r" {
        ligne := Trim(A_LoopField)
        pos := InStr(ligne, "=")
        if (ligne = "" || !pos)
            continue
        phrases[Trim(SubStr(ligne, 1, pos - 1))] := StrReplace(Trim(SubStr(ligne, pos + 1)), "\n", "`n")
    }
    TEXTES[code] := phrases
}

ChargerTextes() {
    AjouterTextes("fr", "
    (
    ecrire          = Écrire et traduire
    touche_ecrire   = Ctrl+Entrée
    lire            = Lire et traduire
    touche_lire     = Triple-clic
    deplacer        = Déplacer la pastille
    touche_deplacer = Glisser
    desactive       = (désactivé)
    lecture         = Traduction au triple-clic
    lecture_on      = Traduction au triple-clic activée
    lecture_off     = Traduction au triple-clic désactivée
    ma_langue       = Ma langue est :
    langue_trad     = Langue traduite en :
    inverser        = Inverser les deux langues
    afficher        = Afficher la pastille
    replacer        = Replacer la pastille en bas à droite
    demarrage       = Lancer au démarrage de Windows
    quitter         = Quitter
    copier          = Copier
    copie           = Traduction copiée
    err_titre       = Traduction impossible
    err_non_envoye  = Ton message n'a pas été envoyé.
    err_trop_long   = Texte trop long (maximum {1} caractères).
    err_connexion   = Google Traduction ne répond pas (connexion internet ?).
    err_refus       = Google Traduction a refusé la demande (code {1}).
    err_reponse     = Réponse inattendue de Google Traduction.
    accueil         = Ctrl+Entrée : traduit ton texte et l'envoie.\nTriple-clic : traduit le texte visé.\nClic droit sur la pastille : menu et langues.
    )")

    AjouterTextes("en", "
    (
    ecrire          = Write and translate
    touche_ecrire   = Ctrl+Enter
    lire            = Read and translate
    touche_lire     = Triple-click
    deplacer        = Move the badge
    touche_deplacer = Drag
    desactive       = (off)
    lecture         = Translate on triple-click
    lecture_on      = Translate on triple-click: on
    lecture_off     = Translate on triple-click: off
    ma_langue       = My language is:
    langue_trad     = Translate into:
    inverser        = Swap the two languages
    afficher        = Show the badge
    replacer        = Move the badge back to the bottom right
    demarrage       = Start with Windows
    quitter         = Exit
    copier          = Copy
    copie           = Translation copied
    err_titre       = Translation failed
    err_non_envoye  = Your message was not sent.
    err_trop_long   = Text too long (maximum {1} characters).
    err_connexion   = Google Translate is not responding (internet connection?).
    err_refus       = Google Translate refused the request (code {1}).
    err_reponse     = Unexpected response from Google Translate.
    accueil         = Ctrl+Enter: translates your text and sends it.\nTriple-click: translates the text you click.\nRight-click the badge: menu and languages.
    )")

    AjouterTextes("es", "
    (
    ecrire          = Escribir y traducir
    touche_ecrire   = Ctrl+Intro
    lire            = Leer y traducir
    touche_lire     = Triple clic
    deplacer        = Mover el indicador
    touche_deplacer = Arrastrar
    desactive       = (desactivado)
    lecture         = Traducir con triple clic
    lecture_on      = Traducción con triple clic activada
    lecture_off     = Traducción con triple clic desactivada
    ma_langue       = Mi idioma es:
    langue_trad     = Traducir a:
    inverser        = Intercambiar los dos idiomas
    afficher        = Mostrar el indicador
    replacer        = Volver a colocar el indicador abajo a la derecha
    demarrage       = Iniciar con Windows
    quitter         = Salir
    copier          = Copiar
    copie           = Traducción copiada
    err_titre       = No se pudo traducir
    err_non_envoye  = Tu mensaje no se ha enviado.
    err_trop_long   = Texto demasiado largo (máximo {1} caracteres).
    err_connexion   = Google Traductor no responde (¿conexión a internet?).
    err_refus       = Google Traductor rechazó la solicitud (código {1}).
    err_reponse     = Respuesta inesperada de Google Traductor.
    accueil         = Ctrl+Intro: traduce tu texto y lo envía.\nTriple clic: traduce el texto señalado.\nClic derecho en el indicador: menú e idiomas.
    )")

    AjouterTextes("pt", "
    (
    ecrire          = Escrever e traduzir
    touche_ecrire   = Ctrl+Enter
    lire            = Ler e traduzir
    touche_lire     = Clique triplo
    deplacer        = Mover o indicador
    touche_deplacer = Arrastar
    desactive       = (desativado)
    lecture         = Traduzir com clique triplo
    lecture_on      = Tradução com clique triplo ativada
    lecture_off     = Tradução com clique triplo desativada
    ma_langue       = Meu idioma é:
    langue_trad     = Traduzir para:
    inverser        = Trocar os dois idiomas
    afficher        = Mostrar o indicador
    replacer        = Recolocar o indicador no canto inferior direito
    demarrage       = Iniciar com o Windows
    quitter         = Sair
    copier          = Copiar
    copie           = Tradução copiada
    err_titre       = Não foi possível traduzir
    err_non_envoye  = Sua mensagem não foi enviada.
    err_trop_long   = Texto longo demais (máximo de {1} caracteres).
    err_connexion   = O Google Tradutor não responde (conexão com a internet?).
    err_refus       = O Google Tradutor recusou o pedido (código {1}).
    err_reponse     = Resposta inesperada do Google Tradutor.
    accueil         = Ctrl+Enter: traduz seu texto e o envia.\nClique triplo: traduz o texto clicado.\nClique direito no indicador: menu e idiomas.
    )")

    AjouterTextes("de", "
    (
    ecrire          = Schreiben und übersetzen
    touche_ecrire   = Strg+Eingabe
    lire            = Lesen und übersetzen
    touche_lire     = Dreifachklick
    deplacer        = Anzeige verschieben
    touche_deplacer = Ziehen
    desactive       = (aus)
    lecture         = Übersetzen per Dreifachklick
    lecture_on      = Übersetzen per Dreifachklick: an
    lecture_off     = Übersetzen per Dreifachklick: aus
    ma_langue       = Meine Sprache ist:
    langue_trad     = Übersetzen in:
    inverser        = Beide Sprachen tauschen
    afficher        = Anzeige einblenden
    replacer        = Anzeige nach unten rechts zurücksetzen
    demarrage       = Mit Windows starten
    quitter         = Beenden
    copier          = Kopieren
    copie           = Übersetzung kopiert
    err_titre       = Übersetzung fehlgeschlagen
    err_non_envoye  = Deine Nachricht wurde nicht gesendet.
    err_trop_long   = Text zu lang (maximal {1} Zeichen).
    err_connexion   = Google Übersetzer antwortet nicht (Internetverbindung?).
    err_refus       = Google Übersetzer hat die Anfrage abgelehnt (Code {1}).
    err_reponse     = Unerwartete Antwort von Google Übersetzer.
    accueil         = Strg+Eingabe: übersetzt deinen Text und sendet ihn.\nDreifachklick: übersetzt den angeklickten Text.\nRechtsklick auf die Anzeige: Menü und Sprachen.
    )")

    AjouterTextes("nl", "
    (
    ecrire          = Schrijven en vertalen
    touche_ecrire   = Ctrl+Enter
    lire            = Lezen en vertalen
    touche_lire     = Driedubbelklik
    deplacer        = Indicator verplaatsen
    touche_deplacer = Slepen
    desactive       = (uit)
    lecture         = Vertalen met driedubbelklik
    lecture_on      = Vertalen met driedubbelklik: aan
    lecture_off     = Vertalen met driedubbelklik: uit
    ma_langue       = Mijn taal is:
    langue_trad     = Vertalen naar:
    inverser        = Beide talen omwisselen
    afficher        = Indicator tonen
    replacer        = Indicator terugzetten rechtsonder
    demarrage       = Starten met Windows
    quitter         = Afsluiten
    copier          = Kopiëren
    copie           = Vertaling gekopieerd
    err_titre       = Vertalen mislukt
    err_non_envoye  = Je bericht is niet verzonden.
    err_trop_long   = Tekst te lang (maximaal {1} tekens).
    err_connexion   = Google Translate reageert niet (internetverbinding?).
    err_refus       = Google Translate heeft het verzoek geweigerd (code {1}).
    err_reponse     = Onverwacht antwoord van Google Translate.
    accueil         = Ctrl+Enter: vertaalt je tekst en verstuurt hem.\nDriedubbelklik: vertaalt de aangeklikte tekst.\nRechtsklik op de indicator: menu en talen.
    )")

    AjouterTextes("no", "
    (
    ecrire          = Skriv og oversett
    touche_ecrire   = Ctrl+Enter
    lire            = Les og oversett
    touche_lire     = Trippelklikk
    deplacer        = Flytt merket
    touche_deplacer = Dra
    desactive       = (av)
    lecture         = Oversett med trippelklikk
    lecture_on      = Oversettelse med trippelklikk: på
    lecture_off     = Oversettelse med trippelklikk: av
    ma_langue       = Mitt språk er:
    langue_trad     = Oversett til:
    inverser        = Bytt om de to språkene
    afficher        = Vis merket
    replacer        = Flytt merket tilbake nederst til høyre
    demarrage       = Start med Windows
    quitter         = Avslutt
    copier          = Kopier
    copie           = Oversettelsen er kopiert
    err_titre       = Oversettelsen mislyktes
    err_non_envoye  = Meldingen din ble ikke sendt.
    err_trop_long   = Teksten er for lang (maks {1} tegn).
    err_connexion   = Google Oversetter svarer ikke (internettilkobling?).
    err_refus       = Google Oversetter avviste forespørselen (kode {1}).
    err_reponse     = Uventet svar fra Google Oversetter.
    accueil         = Ctrl+Enter: oversetter teksten din og sender den.\nTrippelklikk: oversetter teksten du klikker på.\nHøyreklikk på merket: meny og språk.
    )")

    AjouterTextes("pl", "
    (
    ecrire          = Pisz i tłumacz
    touche_ecrire   = Ctrl+Enter
    lire            = Czytaj i tłumacz
    touche_lire     = Potrójne kliknięcie
    deplacer        = Przesuń wskaźnik
    touche_deplacer = Przeciągnij
    desactive       = (wyłączone)
    lecture         = Tłumaczenie potrójnym kliknięciem
    lecture_on      = Tłumaczenie potrójnym kliknięciem włączone
    lecture_off     = Tłumaczenie potrójnym kliknięciem wyłączone
    ma_langue       = Mój język to:
    langue_trad     = Tłumacz na:
    inverser        = Zamień oba języki
    afficher        = Pokaż wskaźnik
    replacer        = Przywróć wskaźnik w prawy dolny róg
    demarrage       = Uruchamiaj z systemem Windows
    quitter         = Zakończ
    copier          = Kopiuj
    copie           = Skopiowano tłumaczenie
    err_titre       = Nie udało się przetłumaczyć
    err_non_envoye  = Twoja wiadomość nie została wysłana.
    err_trop_long   = Tekst jest za długi (maksymalnie {1} znaków).
    err_connexion   = Tłumacz Google nie odpowiada (połączenie z internetem?).
    err_refus       = Tłumacz Google odrzucił żądanie (kod {1}).
    err_reponse     = Nieoczekiwana odpowiedź Tłumacza Google.
    accueil         = Ctrl+Enter: tłumaczy tekst i go wysyła.\nPotrójne kliknięcie: tłumaczy wskazany tekst.\nPrawy przycisk na wskaźniku: menu i języki.
    )")

    AjouterTextes("ro", "
    (
    ecrire          = Scrie și traduce
    touche_ecrire   = Ctrl+Enter
    lire            = Citește și traduce
    touche_lire     = Triplu clic
    deplacer        = Mută indicatorul
    touche_deplacer = Trage
    desactive       = (dezactivat)
    lecture         = Traducere cu triplu clic
    lecture_on      = Traducerea cu triplu clic este activată
    lecture_off     = Traducerea cu triplu clic este dezactivată
    ma_langue       = Limba mea este:
    langue_trad     = Tradu în:
    inverser        = Inversează cele două limbi
    afficher        = Afișează indicatorul
    replacer        = Readu indicatorul în dreapta jos
    demarrage       = Pornește odată cu Windows
    quitter         = Ieșire
    copier          = Copiază
    copie           = Traducere copiată
    err_titre       = Traducere eșuată
    err_non_envoye  = Mesajul tău nu a fost trimis.
    err_trop_long   = Text prea lung (maximum {1} caractere).
    err_connexion   = Google Traducere nu răspunde (conexiune la internet?).
    err_refus       = Google Traducere a refuzat cererea (cod {1}).
    err_reponse     = Răspuns neașteptat de la Google Traducere.
    accueil         = Ctrl+Enter: traduce textul și îl trimite.\nTriplu clic: traduce textul vizat.\nClic dreapta pe indicator: meniu și limbi.
    )")
}
