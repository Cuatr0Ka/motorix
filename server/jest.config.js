// Configuración de Jest en modo ES Modules.
// Las pruebas comparten la base motorix_test, por eso se ejecutan en serie.
export default {
  testEnvironment: 'node',
  transform: {},
  maxWorkers: 1,
  setupFilesAfterEnv: ['<rootDir>/tests/helpers/setup.js'],
  testMatch: ['<rootDir>/tests/**/*.test.js'],
};
