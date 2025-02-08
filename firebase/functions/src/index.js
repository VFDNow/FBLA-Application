// import { DocumentSnapshot, FieldValue } from "firebase-admin/firestore";
// import { FirestoreEvent } from "firebase-functions/firestore";

const { logger } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const admin = require("firebase-admin");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

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
    const ownerUid = classData["Owner"];

    const db = getFirestore();

    const ownerDoc = await db.collection("users").doc(ownerUid).get();
    const ownerData = ownerDoc.data();

    if (!ownerData) {
      logger.error("Owner data is undefined");
      return;
    }

    db.collection("users")
      .doc(ownerUid)
      .update({
        Classes: admin.firestore.FieldValue.arrayUnion([
          {
            "Class Icon": classData["Class Icon"],
            "Class Id": classId,
            "Class Name": classData["Class Name"],
            "Teacher Name": `${ownerData["User First"]} ${ownerData["User Last"]}`,
          },
        ]),
      });
  }
);
