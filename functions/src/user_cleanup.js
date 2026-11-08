// =======================================================
// USER DATA CLEAN-UP (account deleted)
// =======================================================
//
// The app deletes the user's Firestore data itself before
// deleting the account. This is the safety net: when a
// Firebase Auth account is deleted (from the app or the
// Firebase console), everything under users/{uid} is
// removed, including the scans sub-collection.
//
// Pure logic, so it can be tested with a fake database.
// =======================================================

'use strict';

/**
 * Deletes users/{uid} and all its sub-collections.
 *
 * @param {object} args
 * @param {{doc: (path: string) => any, recursiveDelete: (ref: any) => Promise<void>}} args.db
 * @param {string} args.uid
 */
async function deleteUserData({ db, uid }) {
  if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
    throw new Error('Invalid user id.');
  }

  await db.recursiveDelete(db.doc(`users/${uid}`));
}

module.exports = { deleteUserData };
