
const { logger } = require("firebase-functions");
// const { onRequest } = require("firebase-functions/v2/https");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

// const admin = require("firebase-admin");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

//http://127.0.0.1:5001/fbla-app-fda42/us-central1/onClassJoin?classId=dcgQSCcz94Ks7Rzsp1oY&userId=FC5ryn30FOSmHBDGydMb

exports.onClassJoin = onCall(async (request) => {
  const classId = request.data.classId;
  const userId = request.auth.uid;

  const db = getFirestore();
  const userDoc = db.collection("users").doc(userId);
  const classDoc = db.collection("classes").doc(classId);
  const classData = (await classDoc.get()).data();
  const userData = (await userDoc.get()).data();
  const teacherData = (await db.collection("users").doc(classData["owner"]).get()).data();

  for (student in classData["students"] ?? []) {
    if (student.studentId ?? "" == userId) {
      return {
        res: false,
        result: `Error! User already in class.`
      }
    }
  }

  // Add class to the users class list
  if (!userData["classes"] || userData["classes"].length <= 0) {
    userDoc.set({
      classes: [
        {
          classIcon: classData["classIcon"],
          classId: classId,
          className: classData["className"],
          teacherName: `${teacherData["userFirst"]} ${teacherData["userLast"]}`,
        },
      ],
    }, { merge: true })
  } else {
    userDoc.update({
      classes: FieldValue.arrayUnion({
        classIcon: classData["classIcon"] ?? "General",
        classId: classId,
        className: classData["className"] ?? "Class",
        teacherName: `${teacherData["userFirst"]} ${teacherData["userLast"]}` ?? "",
      }),
    })
  }

  // Add user to classes students list
  if (!classData["students"]) {
    classDoc.set({
      students: [
        {
          studentId: userId,
          studentIcon: userData["userImageSeed"] ?? "abc",
          userName: `${userData["userFirst"]} ${userData["userLast"]}` ?? "Student Name",
        }
      ]
    }, { merge: true })
  } else {
    classDoc.update({
      students: FieldValue.arrayUnion({
        studentId: userId,
        studentIcon: userData["userImageSeed"] ?? "abc",
        userName: `${userData["userFirst"]} ${userData["userLast"]}` ?? "Student Name",
      })
    })
  }

  return {
    res: true,
    result: `User Succesfully joined class: ${classData["className"] ?? "className"}`
  }
  
});

// Runs when a class is created.
// Updates the owning users classes data to include the new class, and adds a new invite link to invites
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

    // 
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
            classes: [
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
        classes: FieldValue.arrayUnion({
          classIcon: classData["classIcon"] ?? "General",
          classId: classId,
          className: classData["className"] ?? "Class",
          teacherName: `${ownerData["userFirst"] ?? "Teacher"} ${
            ownerData["userLast"] ?? ""
          }`,
        }),
      });
    }

    // Add invite link to database
    db.collection("invites").doc().set({
      classId: classId,
      className: classData["className"] ?? "Class",
      classIcon: classData["classIcon"] ?? "General",
      classHour: classData["classHour"] ?? "Hour",
      classDesc: classData["classDesc"] ?? "Desc",
      teacherName: `${ownerData["userFirst"] ?? "Teacher"} ${
            ownerData["userLast"] ?? ""
          }`,
    });
  }
);
