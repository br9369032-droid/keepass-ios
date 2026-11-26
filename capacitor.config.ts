import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'xyz.666415.keepass',
  appName: 'KeePass',
  webDir: 'www',
  // CapacitorHttp: route fetch()/XMLHttpRequest through native NSURLSession.
  // That bypasses the WebView CORS check, so the native app can talk to
  // dav.jianguoyun.com directly (no Cloudflare Worker proxy needed).
  // The web version does not have this and still uses the proxy.
  plugins: {
    CapacitorHttp: {
      enabled: true
    }
  }
};

export default config;
