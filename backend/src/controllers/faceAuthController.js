import db from "../config/db.js";
import jwt from "jsonwebtoken";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import fetch from "node-fetch";
import dotenv from "dotenv";
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const faceLogin = async (req, res) => {
  const MIN_CONFIDENCE = 85;
  try {
    const { live_image_base64 } = req.body;

    if (!live_image_base64) {
      return res.status(400).json({ message: "Foto wajah tidak ditemukan" });
    }

    // Ambil semua user yang punya foto wajah
    const [users] = await db.query(
      "SELECT id, name, email, face_image FROM users WHERE face_image IS NOT NULL",
    );

    if (users.length === 0) {
      return res.status(404).json({ message: "Tidak ada user terdaftar" });
    }

    let matchedUser = null;
    let highestConfidence = 0;

    // Bandingkan wajah dengan setiap user
    for (const user of users) {
      const storedImagePath = path.join(
        __dirname,
        "../../uploads",
        user.face_image,
      );

      if (!fs.existsSync(storedImagePath)) continue;

      try {
        await new Promise((resolve) => setTimeout(resolve, 500));

        const response = await fetch(
          `${process.env.FACE_SERVICE_URL}/compare`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              live_image: live_image_base64,
              stored_image_path: storedImagePath,
            }),
          },
        );

        const result = await response.json();
        const confidence = result.confidence ?? 0;

        console.log(
          `User ${user.id} (${user.name}): match=${result.match}, confidence=${result.confidence}`,
        );


        if (
          result.match &&
          confidence > highestConfidence &&
          confidence >= MIN_CONFIDENCE
        ) {
          highestConfidence = confidence;
          matchedUser = user;
        }

        if (highestConfidence >= 85) break;
        
      } catch (err) {
        console.error(`Error comparing with user ${user.id}:`, err);
        continue;
      }
    }

    if (!matchedUser) {
      return res.status(401).json({ message: "Wajah tidak dikenali" });
    }

    // Buat JWT token
    const token = jwt.sign(
      { id: matchedUser.id, email: matchedUser.email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" },
    );

    return res.status(200).json({
      message: "Login berhasil",
      token,
      user: {
        id: matchedUser.id,
        name: matchedUser.name,
        email: matchedUser.email,
        face_image: matchedUser.face_image,
        confidence: highestConfidence,
      },
    });
  } catch (error) {
    console.error("Face login error:", error.message);
    console.error("Full error nya:", error);
    return res
      .status(500)
      .json({ message: "Server error", detail: error.message });
  }
};
