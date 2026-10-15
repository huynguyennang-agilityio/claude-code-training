from pydantic import BaseModel, ConfigDict, HttpUrl


class MedalRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    image_url: HttpUrl
