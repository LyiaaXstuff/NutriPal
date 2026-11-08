'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { deleteUserData } = require('../src/user_cleanup');

function fakeDb() {
  const deleted = [];

  return {
    deleted,
    doc: (path) => ({ path }),
    recursiveDelete: async (ref) => {
      deleted.push(ref.path);
    },
  };
}

test('deletes the whole users/{uid} tree', async () => {
  const db = fakeDb();

  await deleteUserData({ db, uid: 'abcDEF123_-' });

  assert.deepEqual(db.deleted, ['users/abcDEF123_-']);
});

test('refuses ids that could point somewhere else', async () => {
  const db = fakeDb();

  await assert.rejects(deleteUserData({ db, uid: '../other' }));
  await assert.rejects(deleteUserData({ db, uid: '' }));
  await assert.rejects(deleteUserData({ db, uid: null }));

  assert.deepEqual(db.deleted, []);
});
