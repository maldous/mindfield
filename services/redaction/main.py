import os
import logging
from typing import List, Optional
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import RecognizerResult, OperatorConfig
import io
from PIL import Image
import pytesseract
from pdf2image import convert_from_bytes

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Presidio engines
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

app = FastAPI(
    title="MindField PII Redaction Service",
    description="PII detection and anonymization using Microsoft Presidio",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if os.getenv("NODE_ENV") == "development" else ["https://mindfield.local"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TextAnalysisRequest(BaseModel):
    text: str
    language: str = "en"
    entities: Optional[List[str]] = None
    score_threshold: float = 0.35

class TextAnonymizationRequest(BaseModel):
    text: str
    language: str = "en"
    entities: Optional[List[str]] = None
    score_threshold: float = 0.35
    anonymization_config: Optional[dict] = None

class PIIResult(BaseModel):
    entity_type: str
    start: int
    end: int
    score: float
    text: str

class AnalysisResponse(BaseModel):
    original_text: str
    pii_entities: List[PIIResult]
    has_pii: bool

class AnonymizationResponse(BaseModel):
    original_text: str
    anonymized_text: str
    pii_entities: List[PIIResult]

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "service": "pii-redaction", "presidio_version": "2.2.358"}

@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_text(request: TextAnalysisRequest):
    """Analyze text for PII entities"""
    try:
        # Analyze text for PII
        results = analyzer.analyze(
            text=request.text,
            language=request.language,
            entities=request.entities,
            score_threshold=request.score_threshold
        )
        
        # Convert results to response format
        pii_entities = [
            PIIResult(
                entity_type=result.entity_type,
                start=result.start,
                end=result.end,
                score=result.score,
                text=request.text[result.start:result.end]
            )
            for result in results
        ]
        
        return AnalysisResponse(
            original_text=request.text,
            pii_entities=pii_entities,
            has_pii=len(pii_entities) > 0
        )
        
    except Exception as e:
        logger.error(f"Error analyzing text: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@app.post("/anonymize", response_model=AnonymizationResponse)
async def anonymize_text(request: TextAnonymizationRequest):
    """Anonymize PII in text"""
    try:
        # First analyze the text
        analysis_results = analyzer.analyze(
            text=request.text,
            language=request.language,
            entities=request.entities,
            score_threshold=request.score_threshold
        )
        
        # Default anonymization config
        default_config = {
            "DEFAULT": OperatorConfig("replace", {"new_value": "[REDACTED]"}),
            "PHONE_NUMBER": OperatorConfig("replace", {"new_value": "[PHONE]"}),
            "EMAIL_ADDRESS": OperatorConfig("replace", {"new_value": "[EMAIL]"}),
            "CREDIT_CARD": OperatorConfig("replace", {"new_value": "[CREDIT_CARD]"}),
            "PERSON": OperatorConfig("replace", {"new_value": "[PERSON]"}),
            "LOCATION": OperatorConfig("replace", {"new_value": "[LOCATION]"}),
            "DATE_TIME": OperatorConfig("replace", {"new_value": "[DATE]"}),
            "IP_ADDRESS": OperatorConfig("replace", {"new_value": "[IP_ADDRESS]"}),
            "IBAN_CODE": OperatorConfig("replace", {"new_value": "[IBAN]"}),
            "AU_ABN": OperatorConfig("replace", {"new_value": "[ABN]"}),
            "AU_ACN": OperatorConfig("replace", {"new_value": "[ACN]"}),
            "AU_TFN": OperatorConfig("replace", {"new_value": "[TFN]"}),
        }
        
        # Use custom config if provided
        anonymization_config = request.anonymization_config or default_config
        
        # Anonymize the text
        anonymized_result = anonymizer.anonymize(
            text=request.text,
            analyzer_results=analysis_results,
            operators=anonymization_config
        )
        
        # Convert analysis results to response format
        pii_entities = [
            PIIResult(
                entity_type=result.entity_type,
                start=result.start,
                end=result.end,
                score=result.score,
                text=request.text[result.start:result.end]
            )
            for result in analysis_results
        ]
        
        return AnonymizationResponse(
            original_text=request.text,
            anonymized_text=anonymized_result.text,
            pii_entities=pii_entities
        )
        
    except Exception as e:
        logger.error(f"Error anonymizing text: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Anonymization failed: {str(e)}")

    @app.post("/analyze-document", response_model=AnalysisResponse)
    async def analyze_document(req: UploadFile = File(...)):
        """Analyze uploaded document for PII via OCR (Tesseract)"""
        content = await req.read()
        text = ""
        if req.content_type == "application/pdf":
            pages = convert_from_bytes(content)
            for img in pages:
                text += pytesseract.image_to_string(img)
        else:
            img = Image.open(io.BytesIO(content))
            text = pytesseract.image_to_string(img)

        # now run the normal analyzer on `text`
        results = analyzer.analyze(text=text, language="en")
        pii = [PIIResult(... ) for r in results]
        return AnalysisResponse(original_text=text, pii_entities=pii, has_pii=bool(pii))

    except Exception as e:
        logger.error(f"Error analyzing document: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Document analysis failed: {str(e)}")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 3000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_level="info",
        reload=os.getenv("NODE_ENV") == "development"
    )
