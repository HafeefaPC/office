import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-client-info, apikey, x-requested-with",
  "Access-Control-Max-Age": "86400"
};

console.log("Edge function loaded successfully");

serve(async (req) => {
  console.log(`Received ${req.method} request to send-verification-email`);
  
  try {
    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      console.log("Handling CORS preflight request");
      return new Response(null, {
        status: 200,
        headers: corsHeaders
      });
    }

    // Only allow POST requests
    if (req.method !== "POST") {
      console.log(`Method ${req.method} not allowed`);
      return new Response(JSON.stringify({
        error: "Method not allowed"
      }), {
        status: 405,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }

    console.log("Processing POST request");
    
    // Parse request body
    const body = await req.json();
    console.log("Request body parsed:", body);

    // Validate required fields
    const { fromEmail, toEmail, employeeName, officeName, verificationCode } = body;
    
    if (!fromEmail || !toEmail || !employeeName || !officeName || !verificationCode) {
      console.log("Missing required fields");
      return new Response(JSON.stringify({
        error: "Missing required fields",
        required: ["fromEmail", "toEmail", "employeeName", "officeName", "verificationCode"]
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }

    console.log("All required fields present, processing email request");
    console.log(`Sending verification email from ${fromEmail} to ${toEmail}`);
    console.log(`Employee: ${employeeName}, Office: ${officeName}, Code: ${verificationCode}`);

    // Simulate successful email sending
    // In production, integrate with your preferred email service here
    // For example, using SendGrid, Resend, or SMTP
    
    const responseData = {
      success: true,
      message: "Verification email sent successfully",
      timestamp: new Date().toISOString(),
      data: {
        fromEmail,
        toEmail,
        employeeName,
        officeName,
        verificationCode
      }
    };

    console.log("Sending success response:", responseData);

    return new Response(JSON.stringify(responseData), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });

  } catch (error) {
    console.error("Edge function error:", error);
    
    return new Response(JSON.stringify({
      success: false,
      error: "Internal server error",
      message: error.message || "Unknown error occurred",
      timestamp: new Date().toISOString()
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});