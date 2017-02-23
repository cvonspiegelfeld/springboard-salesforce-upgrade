public class Springboard {
	public Springboard_Settings__c settings;
	public static String settingsProfileName = null;
	
	/**
	 * Constructor. Make sure settings property is set.
	 */
	public Springboard() {
		this.loadSettings();
	}
	
	/**
	 * Constructor for test classes, or any caller needing to override the active configured profile.
	 */
	public Springboard(String overrideProfileName) {
		Springboard.settingsProfileName = overrideProfileName;
		this.loadSettings();
	}
	
	/**
	 * Loads settings for given profile name.
	 */
	public void loadSettings() {
		// Pull up the active Springboard configuration.
		if (Springboard.settingsProfileName == null) {
			Springboard_Settings_Profile__c sbSettingsProfile = Springboard_Settings_Profile__c.getInstance();
			Springboard.settingsProfileName = (sbSettingsProfile.get('Name__c') == null) ? 'Default' : (String) sbSettingsProfile.get('Name__c');
		}
		this.settings = Springboard_Settings__c.getInstance(Springboard.settingsProfileName);
		if (this.settings == null) {
			throw new SpringboardException('Springboard Settings not available for current profile: ' + Springboard.settingsProfileName);
		}
	}
	
	public static Boolean settingsAreLoaded() {
		return (Springboard.settingsProfileName != null);
	}
	
	
	/**
	 * Encrypt a string using AES256 key and IV from the current Springboard settings.
	 */
	public string encrypt(string str) {
		if (str == '' || str == null) {
			return '';
		}
		// Try to get the default aes key.
		if (String.isBlank(this.settings.Encryptor_Key__c) || String.isBlank(this.settings.Encryptor_IV__c)) {
			return 'Unable to encrypt string because an Encryptor Key or IV setting is missing.';  
		}
		// Convert key and iv to blobs
		Blob key = Blob.valueOf(this.settings.Encryptor_Key__c);
		Blob iv = Blob.valueOf(this.settings.Encryptor_IV__c);
        
		// Convert data to a blob
		Blob data = Blob.valueOf(str);
        
		// Encrypt, encode, return.
		Blob encryptedData = Crypto.encrypt('AES256', key, iv, data); 
		return Encodingutil.urlEncode(Encodingutil.base64Encode(encryptedData), 'utf-8');
	}

	/**
	 * Create a HMAC message (payload) usable by springboard_hmac_parse_payload().
	 */
	public String createHMAC(String drupalUserId, Datetime expiration, String action, List<String> parameters) {
		// Assemble the plain message string, starting with Drupal user ID, timestamp, and action.
		String message = drupalUserId;
		message += '.' + String.valueOf( expiration.getTime() / 1000 );
		message += '.' + action;
		
		// Add any additional parameters.
		for (String param : parameters) {
			message += '.' + param;
		}
		
		return message;
	}
	
	/**
	 * Given a HMAC message (payload) string, return a token to use when verifying message integrity.
	 */
	public String signHMAC(String message) {
		if (String.isBlank(this.settings.Encryptor_Key__c) || String.isBlank(this.settings.Encryptor_IV__c)) {
			throw new SpringboardException('Can\'t generate HMACs without Encryptor Key and IV settings.');
		}

		// Generate an encrypted MAC with the key.
		Blob hmacBlob = Crypto.generateMac('hmacSHA256', Blob.valueOf(message), Blob.valueOf(this.settings.Encryptor_Key__c + this.settings.Encryptor_IV__c));
		
		// Make the HMAC safe for URL use.
		String hmac = Encodingutil.base64Encode(hmacBlob);
		hmac = hmac.replace('+', '-');
		hmac = hmac.replace('/', '_');
		hmac = hmac.replace('=', '');
		hmac = EncodingUtil.urlEncode(hmac, 'utf-8');
		
		return hmac;
	}
	
	private class SpringboardException extends Exception {}
}