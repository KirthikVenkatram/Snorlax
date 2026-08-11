module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  // Clear mock call history (not implementations) between tests so that
  // call-count assertions in one test aren't polluted by calls made in a
  // preceding test within the same file.
  clearMocks: true,
};
