-- Locales.lua
local addonName, addonTable = ...
local L = {}
addonTable.L = L -- Attach to addon namespace instead of global Provisioner

-- Locale Definitions
addonTable.Locales = {
    enUS = {
        name = "EN",
        ["MANAGER_TITLE"] = "Provisioner Manager",
        ["DRAG_ITEM_HERE"] = "Drag Item Here to Track",
        ["STOP_TRACKING"] = "Provisioner: Stopped tracking %s",
        ["START_TRACKING"] = "Provisioner: Tracking %s",
        ["PROFILE_SPECIFIC"] = "Profile Specific",
        ["THEME"] = "Theme: %s",
        ["LOADING"] = "Loading %s...",
        ["LANG"] = "Lang: %s",
        -- Guide
        ["GUIDE_TITLE"] = "Provisioner Guide",
        ["GUIDE_PAGE1"] = "|cFFFFD700Welcome to Provisioner!|r\n\nThis addon helps you track farming goals.\n\n|cFF00BFFF1. Track an Item:|r\n- Drag the item into the Manager's 'Drop' zone.\n\n|cFF00BFFF2. Set a Goal:|r\n- Click the number in the main list to set a target (e.g., 20).\n- When reached: DING! 🔔",
        ["GUIDE_PAGE2"] = "|cFFFFD700Advanced Management|r\n\n|cFF00BFFFProfiles:|r\nCheck 'Profile Specific' to have separate lists per character.\n\n|cFF00BFFFThemes:|r\nUse the Theme button to adjust colors (Colorblind or Preference).\n\n|cFF00BFFFZoom & Minify:|r\n- +/- to resize.\n- Small arrow on the list to collapse the window.",
        ["GUIDE_PAGE3"] = "|cFFFFD700Credits & Info|r\n\nDeveloped with love by |cFF00FF00Mao|r.\n\nCatch me on Twitch for live dev and gameplay!\n\nTwitch Link above.",
        -- Export/Import
        ["BTN_EXPORT"] = "Export List",
        ["BTN_IMPORT"] = "Import List",
        ["EXPORT_TITLE"] = "Export Selection",
        ["IMPORT_TITLE"] = "Import Selection",
        ["EXPORT_DESC"] = "Copy this string to share:",
        ["IMPORT_DESC"] = "Paste string here then click Import:",
        ["IMPORT_SUCCESS"] = "Successfully imported %d items.",
        ["IMPORT_ERROR"] = "Invalid import string.",
        ["IMPORT_BTN_ACTION"] = "Import Now",
        ["BTN_FERMER"] = "Close",
    },
    frFR = {
        name = "FR",
        ["MANAGER_TITLE"] = "Gestionnaire Provisioner",
        ["DRAG_ITEM_HERE"] = "Glissez un objet ici pour le suivre",
        ["STOP_TRACKING"] = "Provisioner: Suivi arrêté pour %s",
        ["START_TRACKING"] = "Provisioner: Suivi démarré pour %s",
        ["PROFILE_SPECIFIC"] = "Profil par Personnage",
        ["THEME"] = "Thème: %s",
        ["LOADING"] = "Chargement %s...",
        ["LANG"] = "Langue: %s",
        -- Guide
        ["GUIDE_TITLE"] = "Guide Provisioner",
        ["GUIDE_PAGE1"] = "|cFFFFD700Bienvenue sur Provisioner !|r\n\nCet addon vous aide à suivre vos objectifs de farm.\n\n|cFF00BFFF1. Suivre un Objet :|r\n- Glissez un objet dans la zone 'Drop' du Manager.\n\n|cFF00BFFF2. Définir un But :|r\n- Cliquez sur le nombre dans la liste principale pour définir un objectif (ex: 20).\n- Quand vous l'atteignez : DING ! 🔔",
        ["GUIDE_PAGE2"] = "|cFFFFD700Gestion Avancée|r\n\n|cFF00BFFFProfils :|r\nCochez 'Profil par Personnage' pour avoir des listes séparées entre vos persos.\n\n|cFF00BFFFThèmes :|r\nUtilisez le bouton Thème pour adapter les couleurs (Daltonisme ou Préférence).\n\n|cFF00BFFFZoom & Minification :|r\n- +/- pour redimensionner.\n- Petite flèche sur la liste pour réduire la fenêtre.",
        ["GUIDE_PAGE3"] = "|cFFFFD700À Propos|r\n\nProvisioner\nProvisionné par le Maître Farmeur |cFFFFD700Mao_KZU|r.\n\nCet outil est forgé avec passion pour tous ceux qui remplissent leurs sacs avec détermination.\n\nSi vous souhaitez soutenir les travaux, rejoignez notre conclave :\n\nLien Twitch ci-dessus.",
        -- Export/Import
        ["BTN_EXPORT"] = "Exporter",
        ["BTN_IMPORT"] = "Importer",
        ["EXPORT_TITLE"] = "Exportation",
        ["IMPORT_TITLE"] = "Importation",
        ["EXPORT_DESC"] = "Copiez ce code pour partager :",
        ["IMPORT_DESC"] = "Collez le code ici et validez :",
        ["IMPORT_SUCCESS"] = "Import réussi de %d objets.",
        ["IMPORT_ERROR"] = "Code d'import invalide.",
        ["IMPORT_BTN_ACTION"] = "Importer Maintenant",
        ["BTN_FERMER"] = "Fermer",
    }
}

-- Fallback metatable function
local function setFallback(t)
    setmetatable(t, {
        __index = function(tbl, k)
            -- Fallback to EN logic would go here, but I'll update EN too for consistency
            local en = addonTable.Locales.enUS
            if en and en[k] then return en[k] end
            return k
        end
    })
end

-- Init Function
function addonTable:LoadLocale(lang)
    if not lang then lang = GetLocale() end
    if not self.Locales[lang] then lang = "enUS" end -- Fallback to EN if locale not supported
    
    wipe(L)
    for k, v in pairs(self.Locales[lang]) do
        L[k] = v
    end
    setFallback(L)
    return lang
end

-- Initial Load (Will be overridden by SavedVars later if set)
addonTable:LoadLocale(GetLocale())
