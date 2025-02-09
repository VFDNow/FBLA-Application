// import { DocumentSnapshot, FieldValue } from "firebase-admin/firestore";
// import { FirestoreEvent } from "firebase-functions/firestore";

const { logger } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

// const admin = require("firebase-admin");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

exports.onClassCreation = onDocumentCreated(
  "/classes/{classId}",
  async (event) => {
    const classId = event.params.classId;
    const classData = event.data.data();

    logger.log("Class created with ID:", classId, "and data:", classData);

    if (!classData) {
      logger.error("Class data is undefined or null.");
      return;
    }

    // Perform additional actions here, such as sending notifications or updating other collections
    const ownerUid = classData["owner"];

    const db = getFirestore();

    const ownerDoc = await db.collection("users").doc(ownerUid).get();
    const ownerData = ownerDoc.data();

    if (!ownerData) {
      logger.error("Owner data is undefined");
      return;
    }

    if (!ownerData["classes"] || ownerData["classes"].length <= 0) {
      db.collection("users")
        .doc(ownerUid)
        .set(
          {
            Classes: [
              {
                classIcon: classData["classIcon"],
                classId: classId,
                className: classData["className"],
                teacherName: `${ownerData["userFirst"]} ${ownerData["userLast"]}`,
              },
            ],
          },
          { merge: true }
        );
    } else {
      var docref = db.collection("users").doc(ownerUid);

      docref.update({
        Classes: FieldValue.arrayUnion({
          classIcon: classData["classIcon"] ?? "General",
          classId: classId,
          className: classData["className"] ?? "Class",
          "Teacher Name": `${ownerData["userFirst"] ?? "Teacher"} ${
            ownerData["userLast"] ?? ""
          }`,
        }),
      });
    }
  }
);
