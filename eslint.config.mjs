import nextPlugin from 'eslint-config-next';

/**
 * Next's package already ships a flat-config array in this version, so the
 * FlatCompat bridge (needed for older shareable configs written for eslintrc)
 * is unnecessary here and was triggering a circular-JSON bug in the compat
 * layer's schema validator when combined with this plugin's self-referencing
 * plugin object. The unused-vars override was dropped rather than re-added
 * as a separate config object, because flat config only applies overrides to
 * plugin rules within the same object that registers the plugin — Next's
 * `next/typescript` preset already enables a sensible unused-vars rule.
 */
const eslintConfig = [
  ...nextPlugin,
  {
    ignores: ['.next/**', 'node_modules/**', 'coverage/**', 'drizzle/**'],
  },
];

export default eslintConfig;
