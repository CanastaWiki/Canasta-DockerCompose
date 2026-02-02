<?php
# =============================================================================
# Global Settings (LocalSettings.php)
# =============================================================================
# This file contains settings that apply to ALL wikis in the farm.
# It is loaded before per-wiki settings, so per-wiki files can override these.
#
# NOTE: All .php files in this directory are automatically loaded in
# alphabetical order. You can organize settings into multiple files.
#
# Examples of what you can add here:
#   - wfLoadExtension( 'VisualEditor' );
#   - wfLoadSkin( 'Vector' );
#   - $wgLanguageCode = "en";
#   - $wgDefaultSkin = "vector-2022";
#   - $wgGroupPermissions['sysop']['interwiki'] = true;
#
# For per-wiki settings, edit config/settings/wikis/<wiki_id>/Settings.php
# =============================================================================

if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

# Add global customizations below:
